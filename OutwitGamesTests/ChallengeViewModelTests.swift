import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct ChallengeViewModelTests {
  @Test
  func viewModelTransitionsFromPreparingToPlayingAndServerResult() async throws {
    let launch = Self.launch()
    let repository = ControllableChallengeRepository(launch: launch)
    let coordinator = AppCoordinator(root: .feed)
    coordinator.push(.challenge(launch.challenge))
    let viewModel = ChallengeViewModel(
      repository: repository,
      coordinator: coordinator,
      challenge: launch.challenge
    )

    await viewModel.start()
    #expect(viewModel.state == .playing(launch))
    #expect(viewModel.hud?.valueText == "0")

    viewModel.handle(.score(9))
    #expect(viewModel.hud?.valueText == "9")

    viewModel.requestExit()
    #expect(viewModel.isExitPromptVisible)
    #expect(viewModel.shouldPauseGame)
    viewModel.dismissExitPrompt()
    #expect(!viewModel.shouldPauseGame)

    let outcome = ChallengeOutcome(
      won: true,
      score: 12,
      target: 12,
      runtimeMilliseconds: 4_000,
      metrics: [:],
      coinsEarned: 5,
      milestoneCoins: 0
    )
    await repository.finish(with: outcome)
    await waitUntil { viewModel.state == .result(launch, outcome) }

    #expect(viewModel.shouldPauseGame)
    viewModel.close()
    #expect(coordinator.path.isEmpty)
  }

  @Test
  func retryRecoversAfterStartFailure() async throws {
    let launch = Self.launch()
    let repository = RetryChallengeRepository(launch: launch)
    let coordinator = AppCoordinator(root: .feed)
    let viewModel = ChallengeViewModel(
      repository: repository,
      coordinator: coordinator,
      challenge: launch.challenge
    )

    await viewModel.start()
    #expect(viewModel.state == .failed(messageKey: "network_timeout"))

    await viewModel.retry()
    #expect(viewModel.state == .playing(launch))
    viewModel.cancel()
  }

  private func waitUntil(
    _ condition: @escaping @MainActor () -> Bool
  ) async {
    for _ in 0..<100 where !condition() { await Task.yield() }
    #expect(condition())
  }

  private static func launch() -> ChallengeLaunch {
    let objective: [String: JSONValue] = [
      "type": .string("min_score"), "target": .number(12),
    ]
    let challenge = FeedChallenge(
      id: 1,
      gameKey: "math",
      title: "Quick Maths",
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
      gameID: "game-1",
      socketToken: "socket-token",
      socketURL: URL(string: "wss://api.example.com/socket")!,
      entryURL: URL(string: "https://games.example.com/index.html?_outwit_session=game-1")!,
      objective: objective,
      level: nil,
      rewardCoins: 5
    )
  }
}

private actor ControllableChallengeRepository: ChallengeRepository {
  let launch: ChallengeLaunch
  let outcomes: AsyncStream<ChallengeOutcome>
  private let continuation: AsyncStream<ChallengeOutcome>.Continuation

  init(launch: ChallengeLaunch) {
    self.launch = launch
    let pair = AsyncStream.makeStream(of: ChallengeOutcome.self)
    outcomes = pair.stream
    continuation = pair.continuation
  }

  func start(_ challenge: FeedChallenge) async throws -> ChallengeLaunch { launch }

  func waitForEnd(of launch: ChallengeLaunch) async throws -> ChallengeOutcome {
    for await outcome in outcomes { return outcome }
    throw CancellationError()
  }

  func finish(with outcome: ChallengeOutcome) {
    continuation.yield(outcome)
    continuation.finish()
  }
}

private actor RetryChallengeRepository: ChallengeRepository {
  let launch: ChallengeLaunch
  private var starts = 0

  init(launch: ChallengeLaunch) {
    self.launch = launch
  }

  func start(_ challenge: FeedChallenge) async throws -> ChallengeLaunch {
    starts += 1
    if starts == 1 { throw AppError.networkTimeout }
    return launch
  }

  func waitForEnd(of launch: ChallengeLaunch) async throws -> ChallengeOutcome {
    try await Task.sleep(for: .seconds(30))
    throw CancellationError()
  }
}
