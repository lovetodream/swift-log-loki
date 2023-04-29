import Foundation

struct BatchEntry {
    var labels: LokiLabels
    var logEntries: [LokiLog]
    
    init(labels: LokiLabels, logEntries: [LokiLog]) {
        self.labels = labels.filterLabels()
        self.logEntries = logEntries
    }
}

private extension LokiLabels {
    
    func filterLabels() -> LokiLabels {
        var result: LokiLabels = [:]
        for (label, value) in self {
            result[label.asLokiLabel()] = value
        }
        return result
    }
}

private extension String {
    
    static let allowedLabelCharacters = CharacterSet(charactersIn: "a"..."z")
        .union(CharacterSet(charactersIn: "A"..."Z"))
        .union(CharacterSet(charactersIn: "0"..."9"))
        .union(["_"])
    
    static let allowedFirstLabelCharacters = CharacterSet(charactersIn: "a"..."z")
        .union(CharacterSet(charactersIn: "A"..."Z"))
        .union(["_"])
    
    func asLokiLabel() -> String {
        guard !isEmpty else { return "_" }
        var newString = map {
            if String.allowedLabelCharacters.contains($0) {
                return $0
            } else {
                return "_"
            }
        }
        if !String.allowedFirstLabelCharacters.contains(newString[0]) {
            newString.insert("_", at: 0)
        }
        return String(newString)
    }
}

private extension CharacterSet {
    
    func contains(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            if !contains(scalar) { return false }
        }
        return true
    }
}
