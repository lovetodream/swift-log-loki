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

import XCTest

@testable import LoggingLoki

final class LokiLogProcessorConfigurationTests: XCTestCase {
    func testLokiURLConstruction() {
        var configuration1 = LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100")
        XCTAssertEqual(configuration1._lokiURL, "http://localhost:3100/loki/api/v1/push")
        configuration1.lokiURL = "http://localhost:3200/"
        XCTAssertEqual(configuration1._lokiURL, "http://localhost:3200/loki/api/v1/push")
        configuration1.lokiURL = "http://localhost:3300"
        XCTAssertEqual(configuration1._lokiURL, "http://localhost:3300/loki/api/v1/push")
        let configuration2 = LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100/")
        XCTAssertEqual(configuration2._lokiURL, "http://localhost:3100/loki/api/v1/push")
    }
}
