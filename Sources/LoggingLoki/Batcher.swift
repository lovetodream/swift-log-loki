import Foundation

class Batcher {
    private let session: LokiSession

    private let lokiURL: URL
    private let sendDataAsJSON: Bool

    private let batchSize: BatchSize
    private let maxBatchTimeInterval: TimeInterval?

    private var currentTimer: Timer? = nil

    var batch: Batch? = nil

    internal init(session: LokiSession,
                  lokiURL: URL,
                  sendDataAsJSON: Bool,
                  batchSize: BatchSize,
                  maxBatchTimeInterval: TimeInterval?) {
        self.session = session
        self.lokiURL = lokiURL
        self.sendDataAsJSON = sendDataAsJSON
        self.batchSize = batchSize
        self.maxBatchTimeInterval = maxBatchTimeInterval

        startTimerIfNeeded()
    }

    func addEntryToBatch(_ log: LokiLog, with labels: LokiLabels) {
        if var batch {
            batch.addEntry(log, with: labels)
            self.batch = batch
        } else {
            var batch = Batch(entries: [])
            batch.addEntry(log, with: labels)
            self.batch = batch
        }
    }

    func startTimerIfNeeded() {
        guard let maxBatchTimeInterval, currentTimer == nil else { return }
        currentTimer = Timer.scheduledTimer(withTimeInterval: maxBatchTimeInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sendBatchIfNeeded()
        }
    }

    func sendBatchIfNeeded() {
        guard let batch else { return }

        if let maxBatchTimeInterval, batch.createdAt.addingTimeInterval(maxBatchTimeInterval) < Date() {
            // ignore other options and send batch now
            return
        }

        switch batchSize {
        case .bytes(let amount):
            if batch.byteSize >= amount {
                // send batch
            }
        case .entries(let amount):
            if batch.totalLogEntries >= amount {
                // send batch
            }
        }
//        session.send(log, with: labels, url: lokiURL, sendAsJSON: sendDataAsJSON) { result in
//            if case .failure(let failure) = result {
//                debugPrint(failure)
//            }
//        }
    }
}
