import Foundation

public extension LokiLogHandler {
    
    enum Labels: String, CaseIterable {
        
        case level
        case label
        case file
        case line
        case function
        case source
    }
}


public struct LabelsSet: ExpressibleByArrayLiteral, Hashable {
    
    public static let empty = LabelsSet(labels: [], isInverted: false)
    public static let all = LabelsSet(labels: [], isInverted: true)
    
    public let labels: Set<String>
    public let isInverted: Bool
    
    public var inverted: LabelsSet {
        LabelsSet(labels: labels, isInverted: !isInverted)
    }
    
    init(labels: Set<String>, isInverted: Bool) {
        self.labels = labels
        self.isInverted = isInverted
    }
    
    public init(_ labels: some Collection<String>) {
        self.init(labels: Set(labels), isInverted: false)
    }
    
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
    
    public func contains(_ label: String) -> Bool {
        labels.contains(label) != isInverted
    }
}

