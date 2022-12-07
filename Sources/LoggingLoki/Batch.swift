import Foundation

struct Batch {
    var entries: [BatchEntry]

    let createdAt = Date()

    var totalLogEntries: Int {
        entries.map { $0.logEntries }.count
    }

    var byteSize: Int {
        MemoryLayout.size(ofValue: self)
    }

    mutating func addEntry(_ log: LokiLog, with labels: LokiLabels) {
        guard let index = entries.firstIndex(where: { $0.labels == labels }) else {
            entries.append(BatchEntry(labels: labels, logEntries: [log]))
            return
        }
        entries[index].logEntries.append(log)
    }
}
