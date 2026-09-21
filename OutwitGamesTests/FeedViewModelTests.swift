import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct FeedViewModelTests {
  @Test
  func initialLoadPublishesCardsWalletAndPlayerIdentity() async {
    let context = makeContext(
      pages: [.success(page(cards: [challenge(id: 1)], cursor: "next"))],
      coins: 240
    )

    await context.viewModel.loadIfNeeded()

    #expect(context.viewModel.phase == .loaded)
    #expect(context.viewModel.cards.map(\.id) == [1])
    #expect(context.viewModel.nextCursor == "next")
    #expect(context.viewModel.walletCoins == 240)
    #expect(context.viewModel.playerInitials == "SP")
    #expect(await context.feed.loadCalls.count == 1)
  }

  @Test
  func approachingTheEndLoadsAndDeduplicatesTheNextPage() async {
    let context = makeContext(pages: [
      .success(page(cards: [challenge(id: 1), challenge(id: 2)], cursor: "next")),
      .success(page(cards: [challenge(id: 2), challenge(id: 3)], cursor: nil)),
    ])
    await context.viewModel.loadIfNeeded()

    await context.viewModel.selectPage(at: 1)

    #expect(context.viewModel.cards.map(\.id) == [1, 2, 3])
    #expect(context.viewModel.nextCursor == nil)
    #expect(!context.viewModel.isLoadingMore)
    #expect(await context.feed.loadCalls.map(\.cursor) == [nil, "next"])
  }

  @Test
  func continuationFailureCanBeRetriedWithTheSameCursor() async {
    let context = makeContext(pages: [
      .success(page(cards: [challenge(id: 1)], cursor: "next")),
      .failure(.networkTimeout),
      .success(page(cards: [challenge(id: 2)], cursor: nil)),
    ])
    await context.viewModel.loadIfNeeded()

    await context.viewModel.selectPage(at: 0)
    #expect(context.viewModel.loadMoreErrorKey == "network_timeout")

    await context.viewModel.retryContinuation()
    #expect(context.viewModel.cards.map(\.id) == [1, 2])
    #expect(context.viewModel.loadMoreErrorKey == nil)
  }

  @Test
  func cancellationDoesNotTurnIntoAVisibleFailure() async {
    let context = makeContext(
      pages: [.success(page(cards: [challenge(id: 1)], cursor: nil))],
      delay: .seconds(1)
    )

    let load = Task { await context.viewModel.loadIfNeeded() }
    while await context.feed.loadCalls.isEmpty { await Task.yield() }
    load.cancel()
    await load.value

    #expect(context.viewModel.cards.isEmpty)
    #expect(context.viewModel.phase == .loading)
  }

  @Test
  func feedIntentsUseTheCoordinatorWithoutStartingBackendGameplay() async {
    let context = makeContext(pages: [.success(page(cards: [challenge(id: 1)], cursor: nil))])
    await context.viewModel.loadIfNeeded()

    context.viewModel.openRewards()
    #expect(context.coordinator.path == [.rewards])

    context.coordinator.back()
    context.viewModel.start(challenge(id: 1))
    #expect(context.coordinator.path == [.challengePreview])
    #expect(await context.feed.loadCalls.count == 1)
  }

  @Test
  func objectiveCopyHighlightsBackendValues() {
    let objective = ChallengeObjective(
      raw: ["type": .string("min_score"), "target": .number(1_200)]
    )

    let copy = ChallengeObjectiveCopyBuilder.make(
      objective: objective,
      locale: Locale(identifier: "en")
    )

    #expect(copy.sentence == "Score 1,200 points.")
    #expect(copy.parts.contains(.init(text: "1,200", isHighlighted: true)))
  }

  private func makeContext(
    pages: [Result<FeedPage, AppError>],
    coins: Int = 0,
    delay: Duration? = nil
  ) -> FeedTestContext {
    let feed = FeedRepositorySpy(results: pages, delay: delay)
    let home = HomeRepositoryStub(wallet: WalletBalance(coins: coins, elixir: 0))
    let coordinator = AppCoordinator(root: .feed)
    let store = InMemoryTokenStore(
      session: AuthSession(
        user: AuthUser(
          id: 91,
          kind: "registered",
          username: "Swift Player",
          phone: "+919876543210",
          externalID: "external-91"
        ),
        apiToken: "api",
        socketToken: "socket",
        refreshToken: "refresh"
      )
    )
    return FeedTestContext(
      viewModel: FeedViewModel(
        feedRepository: feed,
        homeRepository: home,
        tokenStore: store,
        coordinator: coordinator
      ),
      feed: feed,
      coordinator: coordinator
    )
  }

  private func page(cards: [FeedChallenge], cursor: String?) -> FeedPage {
    FeedPage(challenges: cards, milestone: nil, nextCursor: cursor)
  }

  private func challenge(id: Int) -> FeedChallenge {
    FeedChallenge(
      id: id,
      gameKey: "game-\(id)",
      title: "Challenge \(id)",
      objective: ChallengeObjective(raw: ["type": .string("clear_all")]),
      difficulty: 1,
      rewardCoins: 5,
      bundle: FeedGameBundle(
        version: "1",
        url: "https://games.example.com/\(id)/",
        entry: "index.html"
      ),
      media: []
    )
  }
}

private struct FeedTestContext {
  let viewModel: FeedViewModel
  let feed: FeedRepositorySpy
  let coordinator: AppCoordinator
}

private nonisolated struct FeedLoadCall: Equatable, Sendable {
  let count: Int
  let forceRefresh: Bool
  let cursor: String?
}

private actor FeedRepositorySpy: FeedRepository {
  private var results: [Result<FeedPage, AppError>]
  private let delay: Duration?
  private(set) var loadCalls: [FeedLoadCall] = []

  init(results: [Result<FeedPage, AppError>], delay: Duration?) {
    self.results = results
    self.delay = delay
  }

  func load(count: Int, forceRefresh: Bool, cursor: String?) async throws -> FeedPage {
    loadCalls.append(.init(count: count, forceRefresh: forceRefresh, cursor: cursor))
    if let delay { try await Task.sleep(for: delay) }
    guard !results.isEmpty else { throw AppError.invalidRequest }
    return try results.removeFirst().get()
  }
}

private nonisolated struct HomeRepositoryStub: HomeRepository {
  let wallet: WalletBalance

  func loadWallet(forceRefresh: Bool) async throws -> WalletBalance { wallet }
}
