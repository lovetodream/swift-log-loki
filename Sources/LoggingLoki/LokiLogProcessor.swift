//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftLogLoki open source project
//
// Copyright (c) 2024 Timo Zacherl and the SwiftLogLoki project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncAlgorithms
import AsyncHTTPClient
import Logging
import NIOConcurrencyHelpers
import NIOHTTP1
import ServiceLifecycle

/// A configuration object for ``LokiLogProcessor``.
public struct LokiLogProcessorConfiguration: Sendable {
    /// The loki server URL, eg. `http://localhost:3100`.
    public var lokiURL: String {
        didSet {
            _lokiURL =
                if lokiURL.hasSuffix("/") {
                    lokiURL + "loki/api/v1/push"
                } else {
                    lokiURL + "/loki/api/v1/push"
                }
        }
    }
    internal private(set) var _lokiURL: String
    /// HTTP headers to be sent to the Loki server.
    ///
    /// Especially useful for authentication purposes.
    /// E.g. setting a `Authorization: Basic ...` header.
    public var headers: [(String, String)]

    /// The format used to send logs to Loki.
    public var logFormat: LogFormat
    /// The size of a single batch of logs.
    ///
    /// Once this limit is exceeded the batch of logs will be sent to Loki.
    public var batchSize: Int
    /// The maximum amount of time in seconds to elapse until a batch of logs is sent to Loki.
    ///
    /// This limit is set to 5 minutes by default. Even if a batch is not "full" (``batchSize``)
    /// after the end of the interval, it will be sent to Loki.
    /// Setting this interval should prevent leaving logs in memory for too long without sending them.
    public var maxBatchTimeInterval: Duration?

    /// An interval, which indicates the period in which the processor checks for logs to be sent.
    public var exportInterval: Duration = .seconds(5)
    /// A timeout until an export is cancelled.
    public var exportTimeout: Duration = .seconds(30)

    /// Specifies the transport encoding of the payload sent to the Loki backend.
    public var encoding: Encoding

    /// Indicates the format of log messages sent to Loki.
    public struct LogFormat: Sendable {
        public typealias CustomFormatter = @Sendable (Logger.Level, Logger.Message, Logger.Metadata)
            -> String

        enum Code {
            case logfmt
            case structured
            case custom(CustomFormatter)
        }

        let code: Code

        /// Sends `Logger.Metadata` as part of the log line in the logfmt format.
        ///
        ///The line content will be formatted like this:
        /// ```log
        /// [LEVEL] metadata_key=metadata_value msg="my log line content"
        /// ```
        ///
        /// See [https://brandur.org/logfmt](https://brandur.org/logfmt).
        public static let logfmt = LogFormat(code: .logfmt)
        /// Sends `Logger.Metadata` to Loki as structured metadata
        /// and leaves it out of the log line itself.
        ///
        /// The line content will be formatted like this:
        /// ```log
        /// [LEVEL] my log line content
        /// ```
        ///
        /// Note, that the metadata is not part of the log line itself but will be sent as structured metadata.
        ///
        /// See [https://grafana.com/docs/loki/latest/get-started/labels/structured-metadata/](https://grafana.com/docs/loki/latest/get-started/labels/structured-metadata/).
        public static let structured = LogFormat(code: .structured)

        /// A custom format provided by the user.
        public static func custom(_ format: @escaping CustomFormatter) -> Self {
            LogFormat(code: .custom(format))
        }
    }

    /// Transport encoding (content-type) of the body which is sent to Loki.
    public struct Encoding: Sendable {
        enum Code {
            case json
            case protobuf
        }

        let code: Code

        public static let json = Encoding(code: .json)
        public static let protobuf = Encoding(code: .protobuf)
    }

    /// Initializes a configuration.
    /// - Parameters:
    ///   - lokiURL: The URL of the Loki server where to logs will be sent to.
    ///   - headers: A collection of key value pairs that will be sent as HTTP headers to the Loki server.
    ///   - batchSize: The limit of logs in a single batch until they will be sent to Loki.
    ///   - maxBatchTimeInterval: The maximum amount of time a batch of logs will remain in
    ///   memory, before it is sent to Loki, even if the batchSize is not exceeded. Will be omitted if `nil`.
    ///   - logFormat: The format of a log message/line.
    public init(
        lokiURL: String,
        headers: [(String, String)] = [],
        batchSize: Int = 20,
        maxBatchTimeInterval: Duration? = .seconds(60),
        logFormat: LogFormat = .structured
    ) {
        self.lokiURL = lokiURL
        self._lokiURL =
            if lokiURL.hasSuffix("/") {
                lokiURL + "loki/api/v1/push"
            } else {
                lokiURL + "/loki/api/v1/push"
            }
        self.headers = headers
        self.batchSize = batchSize
        self.maxBatchTimeInterval = maxBatchTimeInterval
        self.encoding = .protobuf
        self.logFormat = logFormat
    }
}

/// A service used to process logs and send them to Loki.
///
/// The service is sending logs as long as ``LokiLogProcessor/run()`` is not cancelled.
///
/// It conforms to ``ServiceLifecycle.Service``.
public struct LokiLogProcessor<Clock: _Concurrency.Clock>: Sendable, Service
where Clock.Duration == Duration {
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
                for try await _ in AsyncTimerSequence.repeating(
                    every: configuration.exportInterval, clock: clock
                ).cancelOnGracefulShutdown() {
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
                batch.createdAt.advanced(by: maxBatchTimeInterval) <= clock.now
            {
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
            logger.warning(
                "Timed out exporting logs.", metadata: ["timeout": "\(configuration.exportTimeout)"]
            )
        } catch {
            logger.error("Failed to export logs.", metadata: ["error": "\(error)"])
        }
    }

    func addEntryToBatch(_ log: LokiLog, with labels: [String: String]) {
        let log = makeLog(log)
        continuation.yield((log, labels))
    }

    func makeLog(_ log: LokiLog) -> LokiLog.Transport {
        switch configuration.logFormat.code {
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
    /// Creates a new processor used to send logs to Loki with the given configuration.
    ///
    /// The processor can be used on multiple ``LokiLogHandler``s,
    /// it will manage the logs accordingly.
    ///
    /// - Parameter configuration: A configuration object used to setup the processors behaviour.
    public init(configuration: Configuration) {
        let transformer: LokiTransformer =
            switch configuration.encoding.code {
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
