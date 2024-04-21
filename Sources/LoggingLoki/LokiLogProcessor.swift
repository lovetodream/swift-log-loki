import Logging
import NIOHTTP1
import AsyncHTTPClient
import ServiceLifecycle
import AsyncAlgorithms

public struct LokiLogProcessorConfiguration: Sendable {
    /// The loki server URL, eg. `http://localhost:3100`.
    public var lokiURL: String {
        didSet {
            _lokiURL = if lokiURL.hasSuffix("/") {
                lokiURL + "loki/api/v1/push"
            } else {
                lokiURL + "/loki/api/v1/push"
            }
        }
    }
    internal private(set) var _lokiURL: String
    /// Additional HTTP headers to be sent to the Loki server.
    public var headers: [(String, String)]

    public var metadataFormat: MetadataFormat
    public var batchSize: Int
    public var maxBatchTimeInterval: Duration?

    public var exportInterval: Duration = .seconds(5)
    public var exportTimeout: Duration = .seconds(30)

    /// Specifies the transport encoding of the payload sent to the Loki backend.
    public var encoding: Encoding

    public struct MetadataFormat: Sendable {
        public typealias CustomFormatter = @Sendable (Logger.Level, Logger.Message, Logger.Metadata) -> String

        enum Code {
            case logfmt
            case structured
            case custom(CustomFormatter)
        }

        let code: Code

        /// Sends ``Logger.Metadata`` as part of the log line in the logfmt format.
        ///
        ///The line content will be formatted like this:
        /// ```log
        /// [LEVEL] metadata_key=metadata_value msg="my log line content"
        /// ```
        ///
        /// See [https://brandur.org/logfmt](https://brandur.org/logfmt).
        public static let logfmt = MetadataFormat(code: .logfmt)
        /// Sends ``Logger.Metadata`` to Loki as structured metadata.
        ///
        /// The line content will be formatted like this:
        /// ```log
        /// [LEVEL] my log line content
        /// ```
        ///
        /// Note, that the metadata is not part of the log line itself.
        ///
        /// See [https://grafana.com/docs/loki/latest/get-started/labels/structured-metadata/](https://grafana.com/docs/loki/latest/get-started/labels/structured-metadata/).
        public static let structured = MetadataFormat(code: .structured)

        public static func custom(_ format: @escaping CustomFormatter) -> Self {
            MetadataFormat(code: .custom(format))
        }
    }

    public struct Encoding: Sendable {
        enum Code {
            case json
            case protobuf
        }

        let code: Code

        public static let json = Encoding(code: .json)
        public static let protobuf = Encoding(code: .protobuf)
    }

    public init(
        lokiURL: String,
        headers: [(String, String)] = [],
        batchSize: Int = 10,
        maxBatchTimeInterval: Duration? = .seconds(5 * 60),
        metadataFormat: MetadataFormat = .structured
    ) {
        self.lokiURL = lokiURL
        self._lokiURL = if lokiURL.hasSuffix("/") {
            lokiURL + "loki/api/v1/push"
        } else {
            lokiURL + "/loki/api/v1/push"
        }
        self.headers = headers
        self.batchSize = batchSize
        self.maxBatchTimeInterval = maxBatchTimeInterval
        self.encoding = .protobuf
        self.metadataFormat = metadataFormat
    }
}

public struct LokiLogProcessor<Clock: _Concurrency.Clock>: Sendable, Service where Clock.Duration == Duration {
    final class _Storage: Sendable {
        fileprivate let _value: NIOLockedValueBox<Batch<Clock>?> = NIOLockedValueBox(nil)
    }

    public typealias Configuration = LokiLogProcessorConfiguration

    private let logger = Logger(label: "LokiLogProcessor")

    private let configuration: Configuration

    private let transport: LokiTransport
    private let transformer: LokiTransformer
    private let clock: Clock

    private let storage = _Storage()

    private let stream: AsyncStream<(LokiLog.Transport, [String: String])>
    private let continuation: AsyncStream<(LokiLog.Transport, [String: String])>.Continuation

    init(
        configuration: Configuration,
        transport: LokiTransport,
        transformer: LokiTransformer,
        clock: Clock
    ) {
        self.configuration = configuration
        self.transport = transport
        self.transformer = transformer
        self.clock = clock

        let (stream, continuation) = AsyncStream<(LokiLog.Transport, [String: String])>.makeStream()
        self.stream = stream
        self.continuation = continuation
    }
    
    public func run() async throws {
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask {
                for try await _ in AsyncTimerSequence.repeating(every: configuration.exportInterval, clock: clock).cancelOnGracefulShutdown() {
                    await tick()
                }
            }

            group.addTask {
                await withGracefulShutdownHandler {
                    for await (log, labels) in stream {
                        self.storage._value.withLockedValue { batch in
                            if batch != nil {
                                batch!.addEntry(log, with: labels)
                            } else {
                                batch = Batch(entries: [], createdAt: clock.now)
                                batch!.addEntry(log, with: labels)
                            }
                        }
                    }
                } onGracefulShutdown: {
                    continuation.finish()
                }
            }
        }
    }

    private func tick() async {
        let batch: Batch<Clock>? = self.storage._value.withLockedValue { safeBatch in
            guard let batch = safeBatch else { return nil }

            if let maxBatchTimeInterval = configuration.maxBatchTimeInterval,
               batch.createdAt.advanced(by: maxBatchTimeInterval) <= clock.now {
                safeBatch = nil
                return batch
            }

            if batch.totalLogEntries >= configuration.batchSize {
                safeBatch = nil
                return batch
            }

            return nil
        }
        
        guard let batch else { return }
        do {
            try await withTimeout(configuration.exportTimeout, clock: clock) {
                try await sendBatch(batch)
            }
        } catch is CancellationError {
            logger.warning("Timed out exporting logs.", metadata: ["timeout": "\(configuration.exportTimeout)"])
        } catch {
            logger.error("Failed to export logs.", metadata: ["error": "\(error)"])
        }
    }

    func addEntryToBatch(_ log: LokiLog, with labels: [String: String]) {
        let log = makeLog(log)
        continuation.yield((log, labels))
    }

    func makeLog(_ log: LokiLog) -> LokiLog.Transport {
        switch configuration.metadataFormat.code {
        case .logfmt:
            var line = "[\(log.level.rawValue.uppercased())] message=\"\(log.message)\""
            if let metadata = prettify(log.metadata) {
                line += " \(metadata)"
            }
            return .init(timestamp: .init(), line: line)
        case .structured:
            return .init(
                timestamp: .init(),
                line: "[\(log.level.rawValue.uppercased())] \(log.message)",
                metadata: log.metadata.mapValues(\.description)
            )
        case .custom(let customFormatter):
            let line = customFormatter(log.level, log.message, log.metadata)
            return .init(timestamp: .init(), line: line)
        }
    }

    private func sendBatch(_ batch: Batch<Clock>) async throws {
        var headers = HTTPHeaders(configuration.headers)
        let buffer = try transformer.transform(batch.entries, headers: &headers)
        try await transport
            .transport(buffer, url: configuration._lokiURL, headers: headers)
    }
    
    private func prettify(_ metadata: Logger.Metadata) -> String? {
        if metadata.isEmpty {
            return nil
        } else {
            return metadata.lazy.sorted(by: { $0.key < $1.key }).map { key, value in
                if "\(value)".contains(" ") {
                    "\(key)=\"\(value)\""
                } else {
                    "\(key)=\(value)"
                }
            }.joined(separator: " ")
        }
    }

}

extension LokiLogProcessor where Clock == ContinuousClock {
    public init(configuration: Configuration) {
        let transformer: LokiTransformer = switch configuration.encoding.code {
        case .json:
            LokiJSONTransformer()
        case .protobuf:
            LokiProtobufTransformer()
        }
        let clock = ContinuousClock()
        self.init(
            configuration: configuration,
            transport: HTTPClient.shared,
            transformer: transformer, 
            clock: clock
        )
    }
}
