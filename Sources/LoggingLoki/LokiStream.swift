struct LokiStream: Encodable {
    var stream: Dictionary<String, String>
    var values: Array<Array<String>>

    init(_ logs: [LokiLog], with labels: LokiLabels) {
        self.stream = labels
        self.values = logs.map{ log in
            let timestamp = log.timestamp.timeIntervalSince1970 * 1_000_000_000
            return [String(timestamp), log.message]
        }
    }
}
