struct LokiRequest: Encodable {
    var streams: [LokiStream]

    static func fromBatch(_ batch: Batch) -> LokiRequest {
        var request = LokiRequest(streams: [])
        for entry in batch.entries {
            request.streams.append(LokiStream(entry.logEntries, with: entry.labels))
        }
        return request
    }
}
