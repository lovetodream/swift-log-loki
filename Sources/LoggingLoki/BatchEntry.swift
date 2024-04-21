struct BatchEntry: Sendable {
    var labels: [String: String]
    var logEntries: [LokiLog.Transport]
}
