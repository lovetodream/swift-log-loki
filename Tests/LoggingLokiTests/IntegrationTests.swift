import XCTest
import NIOCore
import NIOHTTP1
import Atomics
import AsyncHTTPClient
@testable import LoggingLoki

final class InspectableTransport: LokiTransport {
    let actual = HTTPClient.shared

    let transported = ManagedAtomic(0)

    func transport(_ data: ByteBuffer, url: String, headers: HTTPHeaders) async throws {
        try await actual.transport(data, url: url, headers: headers)
        transported.wrappingIncrement(ordering: .relaxed)
    }
}

final class IntegrationTests: XCTestCase {
    func testProtobufHappyPath() async throws {
        try await runHappyPath(LokiProtobufTransformer())
    }

    func testJSONHappyPath() async throws {
        try await runHappyPath(LokiJSONTransformer())
    }

    func runHappyPath(_ transformer: LokiTransformer, file: StaticString = #filePath, line: UInt = #line) async throws {
        try await withThrowingDiscardingTaskGroup { group in
            let clock = TestClock()
            let transport = InspectableTransport()
            let processor = LokiLogProcessor(
                configuration: .init(lokiURL: env("XCT_LOKI_URL") ?? "http://localhost:3100", maxBatchTimeInterval: .seconds(10)),
                transport: transport,
                transformer: transformer,
                clock: clock
            )
            var sleepCalls = clock.sleepCalls.makeAsyncIterator()
            group.addTask {
                try await processor.run()
            }
            let handler = LokiLogHandler(label: "com.timozacherl.swift-log-loki-tests", processor: processor)
            logLine(handler: handler)
            await sleepCalls.next()

            // move forward in time until max batch time interval is exceeded
            clock.advance(by: .seconds(5)) // tick
            await sleepCalls.next()
            clock.advance(by: .seconds(5)) // tick
            await sleepCalls.next()

            await sleepCalls.next() // export
            XCTAssertEqual(transport.transported.load(ordering: .relaxed), 1, file: file, line: line)

            group.cancelAll()
        }
    }

    func logLine(handler: LokiLogHandler<TestClock>) {
        handler.log(
            level: .error,
            message: "oh, something bad happened",
            metadata: ["log": "swift"],
            source: "log-loki",
            file: #filePath, 
            function: #function,
            line: #line
        )
    }
}

func env(_ name: String) -> String? {
    getenv(name).flatMap { String(cString: $0) }
}
