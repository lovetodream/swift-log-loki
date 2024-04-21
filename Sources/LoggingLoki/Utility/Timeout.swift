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

func withTimeout<ChildTaskResult>(
    _ timeout: Duration,
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> ChildTaskResult
) async rethrows -> ChildTaskResult where ChildTaskResult: Sendable {
    try await withTimeout(timeout, priority: priority, clock: ContinuousClock(), operation: operation)
}
