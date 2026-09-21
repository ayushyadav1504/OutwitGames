import Foundation
import Testing

@testable import OutwitGames

struct ChallengeRequestAndRepositoryTests {
  @Test
  func startRequestPreservesBackendContract() throws {
    let request = StartChallengeRequest.make(challengeID: 42)
    let started = try request.decodeResponse(
      from: Data(
        #"{"game_id":"game-9","game_key":"math","status":"started","socket_token":"socket-secret","challenge":{"objective":{"type":"min_score","target":12},"level":{"round":2},"reward_coins":7}}"#
          .utf8
      )
    )

    #expect(request.path == "/feed/42/start")
    #expect(request.method == .post)
    #expect(request.requiresAuthentication)
    #expect(started.gameID == "game-9")
    #expect(started.socketToken == "socket-secret")
    #expect(started.objective?["target"]?.intValue == 12)
    #expect(started.rewardCoins == 7)
  }

  @Test
  func repositoryBuildsApprovedEntryURLWithoutPuttingTokenInIt() async throws {
    let client = ChallengeAPIClient()
    let realtime = ChallengeRealtimeStub(
      configuration: ChallengeConfiguration(
        objective: ["type": .string("min_score"), "target": .number(12)],
        level: ["round": .number(2)]
      )
    )
    let repository = DefaultChallengeRepository(
      apiClient: client,
      realtime: realtime,
      configuration: try configuration()
    )

    let launch = try await repository.start(challenge())
    let components = try #require(
      URLComponents(url: launch.entryURL, resolvingAgainstBaseURL: false))

    #expect(launch.gameID == "game-9")
    #expect(launch.socketToken == "socket-secret")
    #expect(components.fragment == nil)
    #expect(components.queryItems?.contains(URLQueryItem(name: "mode", value: "fast")) == true)
    #expect(
      components.queryItems?.contains(URLQueryItem(name: "_outwit_session", value: "game-9"))
        == true)
    #expect(!launch.entryURL.absoluteString.contains("socket-secret"))
    #expect(await realtime.queriedGameIDs == ["game-9"])
  }

  @Test
  func repositoryRejectsAnUnapprovedGameOriginBeforeStartingBackendGame() async throws {
    let client = ChallengeAPIClient()
    let realtime = ChallengeRealtimeStub(
      configuration: ChallengeConfiguration(objective: [:], level: nil)
    )
    let repository = DefaultChallengeRepository(
      apiClient: client,
      realtime: realtime,
      configuration: try configuration()
    )
    let unapproved = FeedChallenge(
      id: 42,
      gameKey: "math",
      title: "Quick Maths",
      objective: ChallengeObjective(raw: ["type": .string("min_score")]),
      difficulty: 1,
      rewardCoins: 5,
      bundle: FeedGameBundle(
        version: "1",
        url: "https://untrusted.example/index/",
        entry: "game.html"
      ),
      media: []
    )

    await #expect(throws: AppError.validation(messageKey: "game_load_failed")) {
      _ = try await repository.start(unapproved)
    }
    #expect(await client.sendCount == 0)
  }

  private func challenge() -> FeedChallenge {
    FeedChallenge(
      id: 42,
      gameKey: "math",
      title: "Quick Maths",
      objective: ChallengeObjective(
        raw: ["type": .string("min_score"), "target": .number(12)]
      ),
      difficulty: 1,
      rewardCoins: 5,
      bundle: FeedGameBundle(
        version: "1",
        url: "https://games.example.com/bundle/?mode=fast#old",
        entry: "index.html"
      ),
      media: []
    )
  }

  private func configuration() throws -> AppConfiguration {
    try AppConfiguration(
      environment: .development,
      apiBaseURL: "https://api.example.com/api",
      socketURL: "wss://api.example.com/socket",
      gameHosts: ["games.example.com"],
      postHogProjectToken: "test-token",
      postHogHostURL: "https://analytics.example.com"
    )
  }
}

private actor ChallengeAPIClient: APIClient {
  private(set) var sendCount = 0

  func send<Response: Sendable>(_ request: APIRequest<Response>) async throws -> Response {
    sendCount += 1
    let data = Data(
      #"{"game_id":"game-9","game_key":"math","status":"started","socket_token":"socket-secret","challenge":{"reward_coins":7}}"#
        .utf8
    )
    return try request.decodeResponse(from: data)
  }
}

private actor ChallengeRealtimeStub: ChallengeRealtimeService {
  let configuration: ChallengeConfiguration
  private(set) var queriedGameIDs: [String] = []

  init(configuration: ChallengeConfiguration) {
    self.configuration = configuration
  }

  func queryChallenge(gameID: String) async throws -> ChallengeConfiguration {
    queriedGameIDs.append(gameID)
    return configuration
  }

  func waitForEnd(gameID: String) async throws -> [String: JSONValue] {
    throw AppError.server()
  }

  func createAdSession(
    gameID: String,
    action: ChallengeAdAction
  ) async throws -> [String: JSONValue] {
    throw AppError.server()
  }

  func spin(gameID: String, nonce: String) async throws -> [String: JSONValue] {
    throw AppError.server()
  }

  func retry(gameID: String, nonce: String) async throws -> [String: JSONValue] {
    throw AppError.server()
  }
}
