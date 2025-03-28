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

import Testing

@testable import LoggingLoki

@Suite struct LokiLogProcessorTests {
    @Test func logFmtFormat() {
        let configuration = LokiLogProcessorConfiguration(
            lokiURL: "http://localhost:3100",
            logFormat: .logfmt
        )
        let processor = LokiLogProcessor(configuration: configuration)
        let raw = LokiLog(
            timestamp: .init(),
            level: .info,
            message: "My log message",
            metadata: ["basic_key": "basic_value", "additional_key": "value with whitespace"]
        )
        let formatted = processor.makeLog(raw)
        #expect(formatted.metadata == nil)
        #expect(formatted.line.starts(with: "[INFO] "))
        #expect(formatted.line.contains("basic_key=basic_value"))
        #expect(formatted.line.contains(#"additional_key="value with whitespace""#))
        #expect(formatted.line.contains(#"message="My log message""#))
    }

    @Test func customFormat() {
        let configuration = LokiLogProcessorConfiguration(
            lokiURL: "http://localhost:3100",
            logFormat: .custom({ level, message, metadata in
                "\(level.rawValue.uppercased()): \(message) [\(metadata.sorted(by: { $0.key < $1.key }).map({ "\($0.key): \($0.value)" }).joined(separator: ", "))]"
            })
        )
        let processor = LokiLogProcessor(configuration: configuration)
        let raw = LokiLog(
            timestamp: .init(),
            level: .info,
            message: "My log message",
            metadata: ["basic_key": "basic_value", "additional_key": "value with whitespace"]
        )
        let formatted = processor.makeLog(raw)
        #expect(formatted.metadata == nil)
        #expect(
            formatted.line
                == #"INFO: My log message [additional_key: value with whitespace, basic_key: basic_value]"#
        )
    }

    @Test func logFmtFormatEmptyMetadata() {
        var configuration = LokiLogProcessorConfiguration(
            lokiURL: "http://localhost:3100",
            logFormat: .logfmt
        )
        configuration.encoding = .json
        let processor = LokiLogProcessor(configuration: configuration)
        let raw = LokiLog(
            timestamp: .init(),
            level: .info,
            message: "My log message",
            metadata: [:]
        )
        let formatted = processor.makeLog(raw)
        #expect(formatted.metadata == nil)
        #expect(formatted.line == #"[INFO] message="My log message""#)
    }
}
