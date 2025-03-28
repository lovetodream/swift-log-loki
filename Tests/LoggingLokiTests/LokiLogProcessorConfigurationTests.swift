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

@Suite struct LokiLogProcessorConfigurationTests {
    @Test func lokiURLConstruction() {
        var configuration1 = LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100")
        #expect(configuration1._lokiURL == "http://localhost:3100/loki/api/v1/push")
        configuration1.lokiURL = "http://localhost:3200/"
        #expect(configuration1._lokiURL == "http://localhost:3200/loki/api/v1/push")
        configuration1.lokiURL = "http://localhost:3300"
        #expect(configuration1._lokiURL == "http://localhost:3300/loki/api/v1/push")
        let configuration2 = LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100/")
        #expect(configuration2._lokiURL == "http://localhost:3100/loki/api/v1/push")
    }
}
