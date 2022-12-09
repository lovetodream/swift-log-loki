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

private let lokiLabelKey = "loki_labels"
