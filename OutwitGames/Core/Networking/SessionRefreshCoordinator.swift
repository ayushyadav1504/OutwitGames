actor SessionRefreshCoordinator {
  private var inFlight: Task<Void, Error>?

  func refresh(operation: @escaping @Sendable () async throws -> Void) async throws {
    if let inFlight {
      return try await inFlight.value
    }

    let task = Task {
      try await operation()
    }
    inFlight = task
    defer { inFlight = nil }
    try await task.value
  }
}
