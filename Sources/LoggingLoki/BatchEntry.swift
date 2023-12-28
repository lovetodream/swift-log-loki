struct BatchEntry: Sendable {
    var labels: LokiLabels
    var logEntries: [LokiLog]
}
