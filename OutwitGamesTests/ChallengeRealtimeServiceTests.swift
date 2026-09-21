import Testing

@testable import OutwitGames

struct ChallengeRealtimeServiceTests {
  @Test
  func matchTopicIsHeldFromQueryUntilServerEndsChallenge() async throws {
    let socket = RecordingSocketSession(
      queryResponse: [
        "objective": .object(["type": .string("min_score"), "target": .number(12)]),
        "level": .object(["round": .number(2)]),
      ]
    )
    let service = DefaultChallengeRealtimeService(
      socketSession: socket,
      gameEndTimeout: .seconds(2)
    )

    let configuration = try await service.queryChallenge(gameID: "game-1")
    #expect(configuration.objective["target"]?.intValue == 12)
    #expect(await socket.acquiredTopics == ["match:game-1"])
    #expect(await socket.releasedTopics.isEmpty)

    let completion = Task { try await service.waitForEnd(gameID: "game-1") }
    await socket.waitForObserver()
    await socket.emit(
      PhoenixEvent(
        reference: nil,
        topic: "match:other-game",
        event: "ended",
        payload: ["won": .bool(false)]
      )
    )
    await socket.emit(
      PhoenixEvent(
        reference: nil,
        topic: "match:game-1",
        event: "ended",
        payload: ["won": .bool(true)]
      )
    )

    #expect(try await completion.value["won"] == .bool(true))
    #expect(await socket.acquiredTopics == ["match:game-1"])
    #expect(await socket.releasedTopics == ["match:game-1"])
    #expect(await socket.startCallCount == 0)
    #expect(await socket.foregroundCallCount == 0)
  }

  @Test
  func cancellationReleasesMatchTopicWithoutStoppingSharedSocket() async throws {
    let socket = RecordingSocketSession(
      queryResponse: ["objective": .object(["type": .string("clear_all")])]
    )
    let service = DefaultChallengeRealtimeService(
      socketSession: socket,
      gameEndTimeout: .seconds(30)
    )
    _ = try await service.queryChallenge(gameID: "game-2")

    let completion = Task { try await service.waitForEnd(gameID: "game-2") }
    await socket.waitForObserver()
    completion.cancel()
    _ = try? await completion.value

    #expect(await socket.releasedTopics == ["match:game-2"])
    #expect(await socket.startCallCount == 0)
    #expect(await socket.foregroundCallCount == 0)
  }
}

private actor RecordingSocketSession: SocketSession {
  let queryResponse: [String: JSONValue]
  private(set) var acquiredTopics: [String] = []
  private(set) var releasedTopics: [String] = []
  private(set) var startCallCount = 0
  private(set) var foregroundCallCount = 0
  private var continuation: AsyncStream<PhoenixEvent>.Continuation?

  init(queryResponse: [String: JSONValue]) {
    self.queryResponse = queryResponse
  }

  func start() async { startCallCount += 1 }
  func setForeground(_ isForeground: Bool) async { foregroundCallCount += 1 }

  func events() async -> AsyncStream<PhoenixEvent> {
    AsyncStream { continuation in
      self.continuation = continuation
    }
  }

  func acquire(topic: String) async throws -> [String: JSONValue] {
    acquiredTopics.append(topic)
    return [:]
  }

  func release(topic: String) async {
    releasedTopics.append(topic)
  }

  func push(
    topic: String,
    event: String,
    payload: [String: JSONValue]
  ) async throws -> [String: JSONValue] {
    #expect(topic.hasPrefix("match:"))
    #expect(event == "query")
    #expect(payload == ["v": .number(1), "q": .string("challenge")])
    return queryResponse
  }

  func emit(_ event: PhoenixEvent) {
    continuation?.yield(event)
  }

  func waitForObserver() async {
    while continuation == nil { await Task.yield() }
  }
}
