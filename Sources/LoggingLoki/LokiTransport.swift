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
import AsyncHTTPClient

protocol LokiTransport: Sendable {
    func transport(_ data: ByteBuffer, url: String, headers: HTTPHeaders) async throws
}

extension HTTPClient: LokiTransport {
    func transport(_ data: ByteBuffer, url: String, headers: HTTPHeaders) async throws {
        var request = HTTPClientRequest(url: url)
        request.headers = headers
        request.body = .bytes(data)
        request.method = .POST
        let response = try await self.execute(request, timeout: .seconds(30))
        guard response.status.code / 100 == 2 else {
            let body = try? await response.body.collect(upTo: 1024 * 1024)
            let payload = body?.getString(
                at: body?.readerIndex ?? 0,
                length: body?.readableBytes ?? 0
            )
            throw LokiResponseError(response: response, payload: payload)
        }
    }
}

struct LokiResponseError: Error {
    var response: HTTPClientResponse
    var payload: String?
}
