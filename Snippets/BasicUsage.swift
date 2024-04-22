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

// snippet.setup
import Logging
import LoggingLoki

let processor = LokiLogProcessor(
    configuration: LokiLogProcessorConfiguration(lokiURL: "http://localhost:3100")
)
LoggingSystem.bootstrap { label in
    LokiLogHandler(label: label, processor: processor)
}

try await withThrowingDiscardingTaskGroup { group in
    group.addTask {
        // The processor has to run in the background to send logs to Loki.
        try await processor.run()
    }
}
// snippet.end
