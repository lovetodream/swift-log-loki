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

struct LokiStream: Encodable, Sendable {
    typealias Value = (String, String, [String: String]?)

    var stream: [String: String]
    var values: [Value]

    init(_ logs: [LokiLog.Transport], with labels: [String: String]) {
        self.stream = labels
        self.values = logs.map { log -> Value in
            let timestamp = Int64(log.timestamp.timeIntervalSince1970 * 1_000_000_000)
            return ("\(timestamp)", log.line, log.metadata?.isEmpty == false ? log.metadata : nil)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stream, forKey: .stream)
        var valuesContainer = container.nestedUnkeyedContainer(forKey: .values)
        for value in values {
            var singleValueContainer = valuesContainer.nestedUnkeyedContainer()
            try singleValueContainer.encode(value.0)
            try singleValueContainer.encode(value.1)
            if let metadata = value.2 {
                try singleValueContainer.encode(metadata)
            }
        }
    }

    enum CodingKeys: CodingKey {
        case stream
        case values
    }
}
