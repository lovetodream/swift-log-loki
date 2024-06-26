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

import Logging

import class Foundation.ProcessInfo

/// ``LokiLogHandler`` is a logging backend for `Logging`.
public struct LokiLogHandler<Clock: _Concurrency.Clock>: LogHandler, Sendable
where Clock.Duration == Duration {

    private let processor: LokiLogProcessor<Clock>

    /// The logger label for the log handler instance.
    ///
    /// This value will be sent to Grafana Loki as the `logger` label.
    public var label: String
    /// The service/program name.
    ///
    /// This value will be sent to Grafana Loki as the `service` label.
    public var service: String
    /// Static labels sent to Loki, which should not depend on the context of a log message.
    public var lokiLabels: [String: String]

    public var metadataProvider: Logger.MetadataProvider?

    /// Creates a log handler, which sends logs to Grafana Loki.
    ///
    /// @Snippet(path: "swift-log-loki/Snippets/BasicUsage", slice: "setup")
    ///
    /// - Parameters:
    ///   - label: Client supplied string describing the logger. Should be unique but not enforced.
    ///            It's also sent to Loki as the `logger` label.
    ///   - service: Client supplied string indicating the service/program name.
    ///              It will be sent to Loki as the `service` label.
    ///   - lokiLabels: Static labels sent to Loki, which should not depend on the context of a log message.
    ///   - processor: Backend service which manages and sends logs to Loki.
    ///   - metadataProvider: A MetadataProvider, used to automatically inject runtime-generated metadata to all logs.
    public init(
        label: String,
        service: String = ProcessInfo.processInfo.processName,
        lokiLabels: [String: String] = [:],
        processor: LokiLogProcessor<Clock>,
        metadataProvider: Logger.MetadataProvider? = nil
    ) {
        self.label = label
        self.service = service
        self.lokiLabels = lokiLabels
        self.processor = processor
        self.metadataProvider = metadataProvider
    }

    /// This method is called when a `LogHandler` must emit a log message. There is no need for the `LogHandler` to
    /// check if the `level` is above or below the configured `logLevel` as `Logger` already performed this check and
    /// determined that a message should be logged.
    ///
    /// - parameters:
    ///     - level: The log level the message was logged at.
    ///     - message: The message to log. To obtain a `String` representation call `message.description`.
    ///     - metadata: The metadata associated to this log message.
    ///     - source: The source where the log message originated, for example the logging module.
    ///     - file: The file the log message was emitted from.
    ///     - function: The function the log line was emitted from.
    ///     - line: The line the log message was emitted from.
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicitMetadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let effectiveMetadata = Self.prepareMetadata(
            base: self.metadata,
            provider: self.metadataProvider,
            explicit: explicitMetadata
        )

        let labels = [
            "service": service,
            "logger": label,
            "source": source,
            "file": file,
            "function": function,
            "line": String(line),
        ].merging(lokiLabels) { old, _ in old }  // message specific labels win!

        processor.addEntryToBatch(
            .init(
                timestamp: .init(),
                level: level,
                message: message,
                metadata: effectiveMetadata
            ), with: labels)
    }

    /// Add, remove, or change the logging metadata.
    ///
    /// - note: `LogHandler`s must treat logging metadata as a value type. This means that the change in metadata must
    ///         only affect this very `LogHandler`.
    ///
    /// - parameters:
    ///    - metadataKey: The key for the metadata item
    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            metadata[key]
        }
        set(newValue) {
            metadata[key] = newValue
        }
    }

    private var prettyMetadata: String?

    /// Get or set the entire metadata storage as a dictionary.
    ///
    /// - note: `LogHandler`s must treat logging metadata as a value type. This means that the change in metadata must
    ///         only affect this very `LogHandler`.
    public var metadata = Logger.Metadata()

    /// Get or set the configured log level.
    ///
    /// - note: `LogHandler`s must treat the log level as a value type. This means that the change in metadata must
    ///         only affect this very `LogHandler`. It is acceptable to provide some form of global log level override
    ///         that means a change in log level on a particular `LogHandler` might not be reflected in any
    ///        `LogHandler`.
    public var logLevel: Logger.Level = .info

    internal static func prepareMetadata(
        base: Logger.Metadata, provider: Logger.MetadataProvider?, explicit: Logger.Metadata?
    ) -> Logger.Metadata {
        var metadata = base

        let provided = provider?.get() ?? [:]

        guard !provided.isEmpty || !((explicit ?? [:]).isEmpty) else {
            // all per-log-statement values are empty
            return base
        }

        if !provided.isEmpty {
            metadata.merge(provided, uniquingKeysWith: { _, provided in provided })
        }

        if let explicit = explicit, !explicit.isEmpty {
            metadata.merge(explicit, uniquingKeysWith: { _, explicit in explicit })
        }

        return metadata
    }

}
