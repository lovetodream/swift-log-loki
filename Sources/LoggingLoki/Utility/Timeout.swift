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

func withTimeout<ClockType: Clock, ChildTaskResult>(
    _ timeout: ClockType.Duration,
    priority: TaskPriority? = nil,
    clock: ClockType,
    operation: @escaping @Sendable () async throws -> ChildTaskResult
) async rethrows -> ChildTaskResult where ChildTaskResult: Sendable {
    try await withThrowingTaskGroup(of: ChildTaskResult.self) { group in
        group.addTask(priority: priority) {
            try await clock.sleep(for: timeout)
            throw CancellationError()
        }
        group.addTask(priority: priority, operation: operation)
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
