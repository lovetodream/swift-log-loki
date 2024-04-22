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

struct LokiRequest: Encodable, Sendable {
    var streams: [LokiStream]

    static func from(entries: [BatchEntry]) -> LokiRequest {
        var request = LokiRequest(streams: [])
        for entry in entries {
            request.streams
                .append(LokiStream(entry.logEntries, with: entry.labels))
        }
        return request
    }
}
