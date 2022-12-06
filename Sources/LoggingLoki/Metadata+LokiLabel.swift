import Foundation
import Logging

public extension Logger.Metadata {
    
    static func lokiLabels(_ labels:  [String: String]) -> Logger.Metadata {
        labels.mapValues { .string($0) }
    }
    
    var lokiLabels: [String: String] {
        get {
            switch self[lokiLabelKey] ?? .dictionary([:]) {
            case let .dictionary(dictionary):
                return dictionary.mapValues(\.description)
            default:
                return [:]
            }
        }
        set {
            self[lokiLabelKey] = newValue.isEmpty ? nil : .dictionary(.lokiLabels(newValue))
        }
    }
}

extension Logger.MetadataValue {
    
    var isEmpty: Bool {
        switch self {
        case .string(let string):
            return string.isEmpty
        case .stringConvertible(let string):
            return string.description.isEmpty
        case .dictionary(let metadata):
            return metadata.isEmpty || !metadata.contains(where: { !$0.value.isEmpty })
        case .array(let array):
            return array.isEmpty || !array.contains(where: { !$0.isEmpty })
        }
    }
    
    func merging(_ other: Logger.MetadataValue) -> Logger.MetadataValue {
        switch (self, other) {
        case let (.array(lhs), .array(rhs)):
            return .array(lhs + rhs)
        case let (.dictionary(lhs), .dictionary(rhs)):
            return .dictionary(lhs.merging(rhs) { $0.merging($1) })
        default: return other
        }
    }
}

private let lokiLabelKey = "loki_labels"
