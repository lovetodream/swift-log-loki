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

import struct Foundation.Date

struct LokiLog {
    var timestamp: Date
    var level: Logger.Level
    var message: Logger.Message
    var metadata: Logger.Metadata

    struct Transport {
        var timestamp: Date
        var line: String
        var metadata: [String: String]?
    }
}
