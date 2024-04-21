import XCTest
import NIOCore
import NIOHTTP1
@testable import LoggingLoki
import struct Logging.Logger

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
    ) async throws { }
}

final class LokiLogHandlerTests: XCTestCase {
    let expectedLogMessage = "Testing swift-log-loki"
    let expectedSource = "swift-log"
    let expectedFile = "TestFile.swift"
    let expectedFunction = "testFunction(_:)"
    let expectedLine: UInt = 42
    let expectedService = "test.swift-log"

    func testLog() async throws {
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
        let handler = LokiLogHandler(label: expectedService, processor: processor)
        
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        
        clock.advance(by: .seconds(5)) // tick
        await sleepCalls.next()

        clock.advance(by: .seconds(5)) // tick
        await sleepCalls.next()

        await sleepCalls.next() // await export

        try checkIfLogExists(for: transformer)
        processing.cancel()
    }

    func testLogWithBiggerBatchSize() async throws {
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
        let handler = LokiLogHandler(label: expectedService, processor: processor)
        
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        
        clock.advance(by: .seconds(5)) // tick
        await sleepCalls.next()

        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        
        clock.advance(by: .seconds(5)) // tick
        await sleepCalls.next()

        XCTAssertNil(transformer.logs?.first)
        
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        
        clock.advance(by: .seconds(5)) // tick
        await sleepCalls.next()
        
        await sleepCalls.next() // await export

        try checkIfLogExists(for: transformer)
        processing.cancel()
    }

    func testLogWithMaxInterval() async throws {
        let transport = TestTransport()
        let transformer = TestTransformer()
        let clock = TestClock()
        let processor = LokiLogProcessor(
            configuration: .init(lokiURL: "http://localhost:3100", maxBatchTimeInterval: .seconds(10)),
            transport: transport,
            transformer: transformer,
            clock: clock
        )
        var sleepCalls = clock.sleepCalls.makeAsyncIterator()
        let processing = Task {
            try await processor.run()
        }
        let handler = LokiLogHandler(label: expectedService, processor: processor)
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        await sleepCalls.next()
        XCTAssertNil(transformer.logs?.first)

        // move forward in time until max batch time interval is exceeded
        clock.advance(by: .seconds(5)) // tick
        await sleepCalls.next()
        clock.advance(by: .seconds(5)) // tick
        await sleepCalls.next()


        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        await sleepCalls.next()
        try checkIfLogExists(for: transformer)
        processing.cancel()
    }

    func checkIfLogExists(for transformer: TestTransformer, file: StaticString = #filePath, line: UInt = #line) throws {
        let firstLog = try XCTUnwrap(transformer.logs?.first, file: file, line: line)

        XCTAssert(firstLog.line.contains(expectedLogMessage), file: file, line: line)
        XCTAssert(firstLog.line.contains(Logger.Level.error.rawValue.uppercased()), file: file, line: line)
        XCTAssertNotNil(firstLog.timestamp, file: file, line: line)
        XCTAssert(transformer.labels?.contains(where: { key, value in
            value == expectedSource && key == "source"
        }) ?? false, file: file, line: line)
        XCTAssert(transformer.labels?.contains(where: { key, value in
            value == expectedFile && key == "file"
        }) ?? false, file: file, line: line)
        XCTAssert(transformer.labels?.contains(where: { key, value in
            value == expectedFunction && key == "function"
        }) ?? false, file: file, line: line)
        XCTAssert(transformer.labels?.contains(where: { key, value in
            value == String(expectedLine) && key == "line"
        }) ?? false, file: file, line: line)
        XCTAssert(transformer.labels?.contains(where: { key, value in
            value == expectedService && key == "service"
        }) ?? false, file: file, line: line)
    }
}
