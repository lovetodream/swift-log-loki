struct LokiRequest: Encodable, Sendable {
    var streams: [LokiStream]

    static func from(entries: [BatchEntry]) -> LokiRequest {
        var request = LokiRequest(streams: [])
        for entry in entries {
            request.streams.append(LokiStream(entry.logEntries, with: entry.labels))
        }
        return request
    }
}
