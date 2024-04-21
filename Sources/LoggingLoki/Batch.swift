import Foundation

struct Batch<Clock: _Concurrency.Clock> {
    var entries: [BatchEntry]

    let createdAt: Clock.Instant

    var totalLogEntries: Int
    
    init(entries: [BatchEntry], createdAt: Clock.Instant) {
        self.entries = entries
        self.createdAt = createdAt
        self.totalLogEntries = entries.flatMap(\.logEntries).count
    }

    mutating func addEntry(_ log: LokiLog.Transport, with labels: [String: String]) {
        if let index = entries.firstIndex(where: { $0.labels == labels }) {
            entries[index].logEntries.append(log)
        } else {
            entries.append(BatchEntry(labels: labels, logEntries: [log]))
        }
        totalLogEntries += 1
    }
}
