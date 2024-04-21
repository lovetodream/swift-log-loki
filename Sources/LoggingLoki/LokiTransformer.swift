import class Foundation.JSONEncoder
import NIOCore
import NIOHTTP1
import Snappy

protocol LokiTransformer: Sendable {
    func transform(_ entries: [BatchEntry], headers: inout HTTPHeaders) throws -> ByteBuffer
}

struct LokiJSONTransformer: LokiTransformer {
    let encoder = JSONEncoder()
    let allocator = ByteBufferAllocator()

    func transform(
        _ entries: [BatchEntry],
        headers: inout HTTPHeaders
    ) throws -> ByteBuffer {
        let buffer = try encoder.encodeAsByteBuffer(
            LokiRequest.from(entries: entries),
            allocator: allocator
        )
        headers.replaceOrAdd(name: "Content-Type", value: "application/json")
        return buffer
    }
}

struct LokiProtobufTransformer: LokiTransformer {
    func transform(
        _ entries: [BatchEntry],
        headers: inout HTTPHeaders
    ) throws -> ByteBuffer {
        let proto = Logproto_PushRequest.with { request in
            request.streams = entries.map { batchEntry in
                Logproto_StreamAdapter.with { stream in
                    stream.labels = "{" + batchEntry.labels.map { "\($0)=\"\($1)\"" }.joined(separator: ",") + "}"
                    stream.entries = batchEntry.logEntries.map { log in
                        Logproto_EntryAdapter.with { entry in
                            entry.timestamp = .init(date: log.timestamp)
                            entry.line = log.line
                            if let metadata = log.metadata {
                                entry.structuredMetadata = metadata.map { key, value in
                                    .with { pair in
                                        pair.name = key
                                        pair.value = value
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        let data = try proto.serializedData().compressedUsingSnappy()
        headers.replaceOrAdd(name: "Content-Type", value: "application/x-protobuf")
        return ByteBuffer(data: data)
    }
}
