import Foundation
import Testing

@testable import OutwitGames

struct ChallengeRewardMapperTests {
  @Test
  func mapsServerSettledSpin() throws {
    let spin = try ChallengeRewardMapper.spin([
      "segment_key": .string("double"),
      "reward_coins": .number(5),
      "segments": .array([
        .object(["key": .string("none"), "label": .string("+0"), "color": .string("#444444")]),
        .object([
          "key": .string("double"), "label": .string("2x"), "color": .string("#D9003A"),
        ]),
      ]),
    ])

    #expect(spin.selectedSegmentKey == "double")
    #expect(spin.rewardCoins == 5)
    #expect(spin.segments.map(\.key) == ["none", "double"])
  }

  @Test
  func rejectsSpinWhenSelectedSegmentIsMissing() {
    #expect(throws: AppError.parsing) {
      _ = try ChallengeRewardMapper.spin([
        "segment_key": .string("missing"),
        "reward_coins": .number(5),
        "segments": .array([.object(["key": .string("one")])]),
      ])
    }
  }
}

struct ChallengeRewardRealtimeTests {
  @Test
  func adSessionUsesTemporaryMatchTopicLease() async throws {
    let socket = RewardSocketSession(response: ["nonce": .string("nonce-1")])
    let service = DefaultChallengeRealtimeService(socketSession: socket)

    let response = try await service.createAdSession(gameID: "game-1", action: .retry)

    #expect(response["nonce"] == .string("nonce-1"))
    #expect(await socket.acquiredTopics == ["match:game-1"])
    #expect(await socket.releasedTopics == ["match:game-1"])
    #expect(
      await socket.pushes == [
        RewardSocketSession.Push(
          topic: "match:game-1",
          event: "ad_session",
          payload: ["type": .string("retry")]
        )
      ])
    #expect(await socket.startCalls == 0)
    #expect(await socket.foregroundCalls == 0)
  }
}

private actor RewardSocketSession: SocketSession {
  struct Push: Equatable, Sendable {
    let topic: String
    let event: String
    let payload: [String: JSONValue]
  }

  let response: [String: JSONValue]
  private(set) var acquiredTopics: [String] = []
  private(set) var releasedTopics: [String] = []
  private(set) var pushes: [Push] = []
  private(set) var startCalls = 0
  private(set) var foregroundCalls = 0

  init(response: [String: JSONValue]) {
    self.response = response
  }

  func start() { startCalls += 1 }
  func setForeground(_ isForeground: Bool) { foregroundCalls += 1 }
  func events() -> AsyncStream<PhoenixEvent> { AsyncStream { $0.finish() } }

  func acquire(topic: String) async throws -> [String: JSONValue] {
    acquiredTopics.append(topic)
    return [:]
  }

  func release(topic: String) { releasedTopics.append(topic) }

  func push(
    topic: String,
    event: String,
    payload: [String: JSONValue]
  ) async throws -> [String: JSONValue] {
    pushes.append(Push(topic: topic, event: event, payload: payload))
    return response
  }
}

@MainActor
struct ChallengeRewardViewModelTests {
  @Test
  func earnedAdAllowsServerRetry() async {
    let launch = Self.launch(gameID: "game-1")
    let nextLaunch = Self.launch(gameID: "game-2")
    let repository = RewardChallengeRepository(launch: launch, nextLaunch: nextLaunch)
    let ads = RewardedAdFake(outcome: .earned)
    let viewModel = Self.viewModel(repository: repository, ads: ads, challenge: launch.challenge)

    await viewModel.start()
    await waitUntil { if case .result = viewModel.state { true } else { false } }
    viewModel.retryWithRewardedAd()
    await waitUntil { viewModel.state == .playing(nextLaunch) }

    #expect(await repository.retryNonces == ["nonce-1"])
    #expect(ads.shows == [.retry])
    viewModel.cancel()
  }

  @Test
  func dismissedAdNeverCallsServerRetry() async {
    let launch = Self.launch(gameID: "game-1")
    let repository = RewardChallengeRepository(launch: launch, nextLaunch: launch)
    let ads = RewardedAdFake(outcome: .dismissed)
    let viewModel = Self.viewModel(repository: repository, ads: ads, challenge: launch.challenge)

    await viewModel.start()
    await waitUntil { if case .result = viewModel.state { true } else { false } }
    viewModel.retryWithRewardedAd()
    await waitUntil { viewModel.actionErrorKey == "rewarded_ad_not_earned" }

    #expect(await repository.retryNonces.isEmpty)
    #expect(ads.shows == [.retry])
    viewModel.cancel()
  }

  private static func viewModel(
    repository: RewardChallengeRepository,
    ads: RewardedAdFake,
    challenge: FeedChallenge
  ) -> ChallengeViewModel {
    ChallengeViewModel(
      repository: repository,
      rewardedAds: ads,
      tokenStore: RewardTokenStore(),
      analytics: NoOpAnalyticsTracker(),
      coordinator: AppCoordinator(root: .feed),
      challenge: challenge
    )
  }

  private static func launch(gameID: String) -> ChallengeLaunch {
    let objective: [String: JSONValue] = [
      "type": .string("min_score"), "target": .number(10),
    ]
    let challenge = FeedChallenge(
      id: 7,
      gameKey: "math",
      title: "Math",
      objective: ChallengeObjective(raw: objective),
      difficulty: 1,
      rewardCoins: 5,
      bundle: FeedGameBundle(
        version: "1",
        url: "https://games.example.com/",
        entry: "index.html"
      ),
      media: []
    )
    return ChallengeLaunch(
      challenge: challenge,
      gameID: gameID,
      socketToken: "socket-token",
      socketURL: URL(string: "wss://api.example.com/socket")!,
      entryURL: URL(string: "https://games.example.com/index.html?_outwit_session=\(gameID)")!,
      objective: objective,
      level: nil,
      rewardCoins: 5
    )
  }

  private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
    for _ in 0..<200 where !condition() { await Task.yield() }
    #expect(condition())
  }
}

private actor RewardChallengeRepository: ChallengeRepository {
  let launch: ChallengeLaunch
  let nextLaunch: ChallengeLaunch
  private(set) var retryNonces: [String] = []

  init(launch: ChallengeLaunch, nextLaunch: ChallengeLaunch) {
    self.launch = launch
    self.nextLaunch = nextLaunch
  }

  func start(_ challenge: FeedChallenge) -> ChallengeLaunch { launch }

  func waitForEnd(of launch: ChallengeLaunch) -> ChallengeOutcome {
    ChallengeOutcome(
      won: false,
      score: 8,
      target: 10,
      runtimeMilliseconds: 1_000,
      metrics: [:],
      coinsEarned: 0,
      milestoneCoins: 0
    )
  }

  func createAdSession(
    for launch: ChallengeLaunch,
    action: ChallengeAdAction
  ) -> ChallengeAdSession {
    ChallengeAdSession(nonce: "nonce-1")
  }

  func amplifyWin(_ launch: ChallengeLaunch, nonce: String) throws -> ChallengeSpin {
    throw AppError.server()
  }

  func retry(_ launch: ChallengeLaunch, nonce: String) -> ChallengeLaunch {
    retryNonces.append(nonce)
    return nextLaunch
  }
}

@MainActor
private final class RewardedAdFake: RewardedAdServing {
  let outcome: RewardedAdOutcome
  private(set) var shows: [RewardedAdPlacement] = []

  init(outcome: RewardedAdOutcome) {
    self.outcome = outcome
  }

  func initialize() async {}
  func load(_ placement: RewardedAdPlacement) async {}

  func show(
    _ placement: RewardedAdPlacement,
    userID: String,
    customData: String
  ) -> RewardedAdOutcome {
    shows.append(placement)
    return outcome
  }
}

private actor RewardTokenStore: TokenStore {
  private var session: AuthSession? = AuthSession(
    user: AuthUser(
      id: 1,
      kind: "registered",
      username: "player",
      phone: "",
      externalID: "external-1"
    ),
    apiToken: "api",
    socketToken: "socket",
    refreshToken: "refresh"
  )

  func loadSession() -> AuthSession? { session }
  func saveSession(_ session: AuthSession) { self.session = session }

  func saveUser(_ user: AuthUser) {
    guard var current = session else { return }
    current.user = user
    session = current
  }

  func clear() { session = nil }
}
