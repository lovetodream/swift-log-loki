struct LokiStream: Encodable {
    var stream: Dictionary<String, String>
    var values: Array<Array<String>>

    init(_ logs: [LokiLog], with labels: LokiLabels) {
        self.stream = labels
        self.values = logs.map{ log in
            let timestamp = Int64(log.timestamp.timeIntervalSince1970 * 1_000_000_000)
            return [String(format: "%.0f", timestamp), log.message]
        }
    }
}
