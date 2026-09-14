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

import NIOCore
import NIOHTTP1
import Testing

import struct Logging.Logger

@testable import LoggingLoki

final class TestTransformer: LokiTransformer, @unchecked Sendable {
    var logs: [LokiLog.Transport]?
    var labels: [String: String]?

    let actual = LokiJSONTransformer()

    func transform(
        _ entries: [BatchEntry],
        headers: inout HTTPHeaders
    ) throws -> ByteBuffer {
        self.logs = entries.first?.logEntries
        self.labels = entries.first?.labels
        return try actual.transform(entries, headers: &headers)
    }
}

final class TestTransport: LokiTransport {
    func transport(
        _ data: ByteBuffer,
        url: String,
        headers: HTTPHeaders
    ) async throws {}
}

@Suite struct LokiLogHandlerTests {
    let expectedLogMessage = "Testing swift-log-loki"
    let expectedSource = "swift-log"
    let expectedFile = "TestFile.swift"
    let expectedFunction = "testFunction(_:)"
    let expectedLine: UInt = 42
    let expectedLabel = "test.swift-log"
    let expectedService = "LokiLogTests"

    @Test
    @available(logLoki 1.0, *)
    func log() async throws {
        let transport = TestTransport()
        let transformer = TestTransformer()
        let clock = TestClock()
        let processor = LokiLogProcessor(
            configuration: .init(lokiURL: "http://localhost:3100", batchSize: 1),
            transport: transport,
            transformer: transformer,
            clock: clock
        )
        var sleepCalls = clock.sleepCalls.makeAsyncIterator()
        let processing = Task {
            try await processor.run()
        }
        let handler = LokiLogHandler(
            label: expectedLabel, service: expectedService, processor: processor)

        handler.log(
            event: .init(
                level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"],
                source: expectedSource, file: expectedFile, function: expectedFunction,
                line: expectedLine
            )
        )

        clock.advance(by: .seconds(5))  // tick
        await sleepCalls.next()

        clock.advance(by: .seconds(5))  // tick
        await sleepCalls.next()

        await sleepCalls.next()  // await export

        try checkIfLogExists(for: transformer)
        processing.cancel()
    }

    @Test
    @available(logLoki 1.0, *)
    func logWithBiggerBatchSize() async throws {
        let transport = TestTransport()
        let transformer = TestTransformer()
        let clock = TestClock()
        let processor = LokiLogProcessor(
            configuration: .init(lokiURL: "http://localhost:3100", batchSize: 3),
            transport: transport,
            transformer: transformer,
            clock: clock
        )
        var sleepCalls = clock.sleepCalls.makeAsyncIterator()
        let processing = Task {
            try await processor.run()
        }
        let handler = LokiLogHandler(
            label: expectedLabel, service: expectedService, processor: processor)

        handler.log(
            event: .init(
                level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"],
                source: expectedSource, file: expectedFile, function: expectedFunction,
                line: expectedLine
            )
        )

        clock.advance(by: .seconds(5))  // tick
        await sleepCalls.next()

        handler.log(
            event: .init(
                level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"],
                source: expectedSource, file: expectedFile, function: expectedFunction,
                line: expectedLine
            )
        )

        clock.advance(by: .seconds(5))  // tick
        await sleepCalls.next()

        #expect(transformer.logs?.first == nil)

        handler.log(
            event: .init(
                level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"],
                source: expectedSource, file: expectedFile, function: expectedFunction,
                line: expectedLine
            )
        )

        clock.advance(by: .seconds(5))  // tick
        await sleepCalls.next()

        await sleepCalls.next()  // await export

        try checkIfLogExists(for: transformer)
        processing.cancel()
    }

    @Test
    @available(logLoki 1.0, *)
    func logWithMaxInterval() async throws {
        let transport = TestTransport()
        let transformer = TestTransformer()
        let clock = TestClock()
        let processor = LokiLogProcessor(
            configuration: .init(
                lokiURL: "http://localhost:3100", maxBatchTimeInterval: .seconds(10)),
            transport: transport,
            transformer: transformer,
            clock: clock
        )
        var sleepCalls = clock.sleepCalls.makeAsyncIterator()
        let processing = Task {
            try await processor.run()
        }
        let handler = LokiLogHandler(
            label: expectedLabel, service: expectedService, processor: processor)
        handler.log(
            event: .init(
                level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"],
                source: expectedSource, file: expectedFile, function: expectedFunction,
                line: expectedLine
            )
        )
        await sleepCalls.next()
        #expect(transformer.logs?.first == nil)

        // move forward in time until max batch time interval is exceeded
        clock.advance(by: .seconds(5))  // tick
        await sleepCalls.next()
        clock.advance(by: .seconds(5))  // tick
        await sleepCalls.next()


        handler.log(
            event: .init(
                level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"],
                source: expectedSource, file: expectedFile, function: expectedFunction,
                line: expectedLine
            )
        )
        await sleepCalls.next()
        try checkIfLogExists(for: transformer)
        processing.cancel()
    }

    @Test
    @available(logLoki 1.0, *)
    func metadataPreparation() {
        let metadata1 = LokiLogHandler<TestClock>.prepareMetadata(
            base: [:], provider: .init({ [:] }), explicit: [:], error: nil)
        #expect(metadata1 == [:])
        let metadata2 = LokiLogHandler<TestClock>.prepareMetadata(
            base: ["hello": "there"], provider: .init({ [:] }), explicit: [:],
            error: TestMetadataError())
        #expect(
            metadata2 == [
                "hello": "there", "error_type": "LoggingLokiTests.TestMetadataError",
                "error_message": "TestMetadataError()",
            ])
        let metadata3 = LokiLogHandler<TestClock>.prepareMetadata(
            base: ["hello": "there"], provider: .init({ ["provided": "metadata"] }), explicit: [:],
            error: nil)
        #expect(metadata3 == ["hello": "there", "provided": "metadata"])
        let metadata4 = LokiLogHandler<TestClock>.prepareMetadata(
            base: ["hello": "there"], provider: .init({ ["provided": "metadata"] }),
            explicit: ["explicit": "metadata"], error: nil)
        #expect(
            metadata4 == ["hello": "there", "provided": "metadata", "explicit": "metadata"])
        let metadata5 = LokiLogHandler<TestClock>.prepareMetadata(
            base: ["hello": "there"], provider: nil, explicit: ["explicit": "metadata"],
            error: TestMetadataError())
        #expect(
            metadata5 == [
                "hello": "there", "explicit": "metadata",
                "error_type": "LoggingLokiTests.TestMetadataError",
                "error_message": "TestMetadataError()",
            ])
        let metadata6 = LokiLogHandler<TestClock>.prepareMetadata(
            base: ["hello": "there"], provider: nil, explicit: nil, error: nil)
        #expect(metadata6 == ["hello": "there"])
        let metadata7 = LokiLogHandler<TestClock>.prepareMetadata(
            base: ["hello": "there"], provider: .init({ ["hello": "how are you"] }), explicit: nil,
            error: nil)
        #expect(metadata7 == ["hello": "how are you"])
        let metadata8 = LokiLogHandler<TestClock>.prepareMetadata(
            base: ["hello": "there"], provider: .init({ ["hello": "how are you"] }),
            explicit: ["hello": "I am fine"], error: nil)
        #expect(metadata8 == ["hello": "I am fine"])
        var handler = LokiLogHandler(
            label: "test", processor: .init(configuration: .init(lokiURL: "")))
        handler[metadataKey: "key"] = "value"
        #expect(handler.metadata == ["key": "value"])
        #expect(handler[metadataKey: "key"] == "value")
    }

    func checkIfLogExists(
        for transformer: TestTransformer, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let firstLog = try #require(transformer.logs?.first)

        #expect(firstLog.line.contains(expectedLogMessage))
        #expect(firstLog.line.contains(Logger.Level.error.rawValue.uppercased()))
        #expect(
            transformer.labels?.contains(where: { key, value in
                value == expectedSource && key == "source"
            }) ?? false)
        #expect(
            transformer.labels?.contains(where: { key, value in
                value == expectedFile && key == "file"
            }) ?? false)
        #expect(
            transformer.labels?.contains(where: { key, value in
                value == expectedFunction && key == "function"
            }) ?? false)
        #expect(
            transformer.labels?.contains(where: { key, value in
                value == String(expectedLine) && key == "line"
            }) ?? false)
        #expect(
            transformer.labels?.contains(where: { key, value in
                value == expectedLabel && key == "logger"
            }) ?? false)
        #expect(
            transformer.labels?.contains(where: { key, value in
                value == expectedService && key == "service"
            }) ?? false)
    }
}

struct TestMetadataError: Error {}
