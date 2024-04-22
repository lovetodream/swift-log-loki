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

import AsyncHTTPClient
import Atomics
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import XCTest

@testable import LoggingLoki

final class InspectableTransport: LokiTransport {
    let actual = HTTPClient.shared

    let transported = ManagedAtomic(0)

    let errored = ManagedAtomic(0)
    let errors: NIOLockedValueBox<[Error]> = NIOLockedValueBox([])

    func transport(_ data: ByteBuffer, url: String, headers: HTTPHeaders) async throws {
        do {
            try await actual.transport(data, url: url, headers: headers)
            transported.wrappingIncrement(ordering: .relaxed)
        } catch {
            errored.wrappingIncrement(ordering: .relaxed)
            errors.withLockedValue { $0.append(error) }
        }
    }
}

final class BadRequestTransformer: LokiTransformer {
    func transform(_ entries: [BatchEntry], headers: inout HTTPHeaders) throws -> ByteBuffer {
        headers.add(name: "Content-Type", value: "application/json")
        var buffer = ByteBuffer()
        buffer.writeString("bad_request :(")
        try buffer.writeJSONEncodable(LokiRequest.from(entries: entries))
        return buffer
    }
}

final class IntegrationTests: XCTestCase {
    func testProtobufHappyPath() async throws {
        try await runHappyPath(LokiProtobufTransformer())
    }

    func testJSONHappyPath() async throws {
        try await runHappyPath(LokiJSONTransformer())
    }

    func testBadRequest() async throws {
        try await withThrowingDiscardingTaskGroup { group in
            let clock = TestClock()
            let transport = InspectableTransport()
            let processor = LokiLogProcessor(
                configuration: .init(
                    lokiURL: env("XCT_LOKI_URL") ?? "http://localhost:3100",
                    maxBatchTimeInterval: .seconds(10)),
                transport: transport,
                transformer: BadRequestTransformer(),
                clock: clock
            )
            var sleepCalls = clock.sleepCalls.makeAsyncIterator()
            group.addTask {
                try await processor.run()
            }
            let handler = LokiLogHandler(
                label: "com.timozacherl.swift-log-loki-tests", processor: processor)
            logLine(handler: handler)
            await sleepCalls.next()

            // move forward in time until max batch time interval is exceeded
            clock.advance(by: .seconds(5))  // tick
            await sleepCalls.next()
            clock.advance(by: .seconds(5))  // tick
            await sleepCalls.next()

            await sleepCalls.next()  // export
            XCTAssertEqual(transport.transported.load(ordering: .relaxed), 0)
            XCTAssertEqual(transport.errored.load(ordering: .relaxed), 1)
            let errors = transport.errors.withLockedValue { $0 }
            let error = try XCTUnwrap(errors.first as? LokiResponseError)
            XCTAssertEqual(error.response.status, .badRequest)

            group.cancelAll()
        }
    }

    func runHappyPath(
        _ transformer: LokiTransformer, file: StaticString = #filePath, line: UInt = #line
    ) async throws {
        try await withThrowingDiscardingTaskGroup { group in
            let clock = TestClock()
            let transport = InspectableTransport()
            let processor = LokiLogProcessor(
                configuration: .init(
                    lokiURL: env("XCT_LOKI_URL") ?? "http://localhost:3100",
                    maxBatchTimeInterval: .seconds(10)),
                transport: transport,
                transformer: transformer,
                clock: clock
            )
            var sleepCalls = clock.sleepCalls.makeAsyncIterator()
            group.addTask {
                try await processor.run()
            }
            let handler = LokiLogHandler(
                label: "com.timozacherl.swift-log-loki-tests", processor: processor)
            logLine(handler: handler)
            await sleepCalls.next()

            // move forward in time until max batch time interval is exceeded
            clock.advance(by: .seconds(5))  // tick
            await sleepCalls.next()
            clock.advance(by: .seconds(5))  // tick
            await sleepCalls.next()

            await sleepCalls.next()  // export
            XCTAssertEqual(
                transport.transported.load(ordering: .relaxed), 1, file: file, line: line)

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
