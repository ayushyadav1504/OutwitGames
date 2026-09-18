import Testing

@testable import OutwitGames

struct SessionRefreshCoordinatorTests {
  @Test
  func concurrentCallersShareOneRefreshOperation() async throws {
    let coordinator = SessionRefreshCoordinator()
    let counter = RefreshCounter()

    async let first: Void = coordinator.refresh {
      await counter.increment()
      try await Task.sleep(for: .milliseconds(50))
    }
    async let second: Void = coordinator.refresh {
      await counter.increment()
      try await Task.sleep(for: .milliseconds(50))
    }

    _ = try await (first, second)

    #expect(await counter.value == 1)
  }
}

private actor RefreshCounter {
  private(set) var value = 0

  func increment() {
    value += 1
  }
}
