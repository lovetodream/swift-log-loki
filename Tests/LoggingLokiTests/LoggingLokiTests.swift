import XCTest
@testable import LoggingLoki
import struct Logging.Logger

class TestSession: LokiSession {
    var logs: [LokiLog]?
    var labels: LokiLabels?
    var headers: [String: String]?

    func send(_ batch: Batch,
              url: URL,
              headers: [String: String],
              auth: LokiAuth,
              sendAsJSON: Bool = false,
              completion: @escaping (Result<StatusCode, Error>) -> Void) {
        self.logs = batch.entries.first?.logEntries
        self.labels = batch.entries.first?.labels
    }
}

final class LoggingLokiTests: XCTestCase {
    let expectedLogMessage = "Testing swift-log-loki"
    let expectedSource = "swift-log"
    let expectedFile = "TestFile.swift"
    let expectedFunction = "testFunction(_:)"
    let expectedLine: UInt = 42
    let expectedService = "test.swift-log"

    func testLog() throws {
        let handler = LokiLogHandler(label: expectedService, lokiURL: URL(string: "http://localhost:3100")!, batchSize: 1, session: TestSession())
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        checkIfLogExists(for: handler)
    }

    func testLogWithBiggerBatchSize() throws {
        let handler = LokiLogHandler(label: expectedService, lokiURL: URL(string: "http://localhost:3100")!, batchSize: 3, session: TestSession())
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        try XCTAssertNil(XCTUnwrap(handler.session as? TestSession).logs?.first)
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        checkIfLogExists(for: handler)
    }

    func testLogWithMaxInterval() async throws {
        let handler = LokiLogHandler(label: expectedService, lokiURL: URL(string: "http://localhost:3100")!, maxBatchTimeInterval: 10, session: TestSession())
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        try XCTAssertNil(XCTUnwrap(handler.session as? TestSession).logs?.first)
        try await Task.sleep(nanoseconds: 15_000_000_000)
        handler.log(level: .error, message: "\(expectedLogMessage)", metadata: ["log": "swift"], source: expectedSource, file: expectedFile, function: expectedFunction, line: expectedLine)
        checkIfLogExists(for: handler)
    }

    func checkIfLogExists(for handler: LokiLogHandler) {
        guard let session = handler.session as? TestSession else {
            XCTFail("Could not cast the Handler's Session to TestSession")
            return
        }

        guard let firstLog = session.logs?.first else {
            XCTFail("Could not get first log from Session")
            return
        }

        XCTAssert(firstLog.message.contains(expectedLogMessage))
        XCTAssert(firstLog.message.contains(Logger.Level.error.rawValue.uppercased()))
        XCTAssertNotNil(firstLog.timestamp)
        XCTAssert(session.labels?.contains(where: { key, value in
            value == expectedSource && key == "source"
        }) ?? false)
        XCTAssert(session.labels?.contains(where: { key, value in
            value == expectedFile && key == "file"
        }) ?? false)
        XCTAssert(session.labels?.contains(where: { key, value in
            value == expectedFunction && key == "function"
        }) ?? false)
        XCTAssert(session.labels?.contains(where: { key, value in
            value == String(expectedLine) && key == "line"
        }) ?? false)
        XCTAssert(session.labels?.contains(where: { key, value in
            value == expectedService && key == "service"
        }) ?? false)
    }
}
