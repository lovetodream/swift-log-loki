import Foundation

final class Batcher: Sendable {
    private let session: LokiSession
    private let headers: [String: String]

    private let lokiURL: URL
    private let sendDataAsJSON: Bool

    private let batchSize: Int
    private let maxBatchTimeInterval: TimeInterval?

    let batch: NIOLockedValueBox<Batch?> = NIOLockedValueBox(nil)

    init(session: LokiSession,
         headers: [String: String],
         lokiURL: URL,
         sendDataAsJSON: Bool,
         batchSize: Int,
         maxBatchTimeInterval: TimeInterval?) {
        self.session = session
        self.headers = headers
        self.lokiURL = lokiURL
        self.sendDataAsJSON = sendDataAsJSON
        self.batchSize = batchSize
        self.maxBatchTimeInterval = maxBatchTimeInterval
    }

    func addEntryToBatch(_ log: LokiLog, with labels: LokiLabels) {
        self.batch.withLockedValue { batch in
            if batch != nil {
                batch!.addEntry(log, with: labels)
            } else {
                batch = Batch(entries: [])
                batch!.addEntry(log, with: labels)
            }
        }
    }

    func sendBatchIfNeeded() {
        self.batch.withLockedValue { safeBatch in
            guard let batch = safeBatch else { return }

            if let maxBatchTimeInterval, batch.createdAt.addingTimeInterval(maxBatchTimeInterval) < Date() {
                sendBatch(batch)
                safeBatch = nil
                return
            }

            if batch.totalLogEntries >= batchSize {
                sendBatch(batch)
                safeBatch = nil
                return
            }
        }
    }

    private func sendBatch(_ batch: Batch) {
        session.send(batch, url: lokiURL, headers: headers, sendAsJSON: sendDataAsJSON) { result in
            if case .failure(let failure) = result {
                debugPrint(failure)
            }
        }
    }
}
