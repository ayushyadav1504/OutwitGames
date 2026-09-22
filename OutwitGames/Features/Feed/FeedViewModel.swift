import Foundation
import Observation

enum FeedPhase: Equatable, Sendable {
  case idle
  case loading
  case loaded
  case empty
  case failed(messageKey: String)
}

@MainActor
@Observable
final class FeedViewModel {
  private static let pageSize = 5
  private static let prefetchRemaining = 2

  private let feedRepository: any FeedRepository
  private let homeRepository: any HomeRepository
  private let tokenStore: any TokenStore
  private let adGate: any FeedAdOpportunityReporting
  private let coordinator: AppCoordinator

  private var revision = 0

  private(set) var phase = FeedPhase.idle
  private(set) var cards: [FeedChallenge] = []
  private(set) var milestone: MilestoneProgress?
  private(set) var nextCursor: String?
  private(set) var currentIndex = 0
  private(set) var isLoadingMore = false
  private(set) var loadMoreErrorKey: String?
  private(set) var walletCoins = 0
  private(set) var playerInitials = "P"
  private(set) var generation = 0
  private(set) var shouldPlaySwipeHint = true
  var alertMessageKey: String?

  init(
    feedRepository: any FeedRepository,
    homeRepository: any HomeRepository,
    tokenStore: any TokenStore,
    adGate: any FeedAdOpportunityReporting = NoOpFeedAdGate(),
    coordinator: AppCoordinator
  ) {
    self.feedRepository = feedRepository
    self.homeRepository = homeRepository
    self.tokenStore = tokenStore
    self.adGate = adGate
    self.coordinator = coordinator
  }

  var hasMore: Bool { nextCursor != nil }

  func loadIfNeeded() async {
    guard phase == .idle else { return }
    await loadFeed()
  }

  func refresh() async {
    await loadFeed()
  }

  func selectPage(at index: Int) async {
    let nextIndex = min(max(index, 0), cards.count)
    let didChangeCard = nextIndex != currentIndex && nextIndex < cards.count
    currentIndex = nextIndex
    if didChangeCard { adGate.cardChanged() }
    guard cards.count - currentIndex - 1 <= Self.prefetchRemaining else { return }
    await loadMore()
  }

  func retryContinuation() async {
    loadMoreErrorKey = nil
    await loadMore()
  }

  func markSwipeHintPlayed() {
    shouldPlaySwipeHint = false
  }

  func openProfile() {
    coordinator.present(.profile)
  }

  func openRewards() {
    coordinator.push(.rewards(.home))
  }

  func start(_ challenge: FeedChallenge) {
    guard challenge.isPlayable else {
      alertMessageKey = "feed.game_unavailable"
      return
    }
    coordinator.push(.challenge(challenge))
  }

  func cancel() {
    revision += 1
  }

  private func loadFeed() async {
    guard phase != .loading else { return }
    revision += 1
    let requestRevision = revision

    phase = .loading
    cards = []
    milestone = nil
    nextCursor = nil
    currentIndex = 0
    isLoadingMore = false
    loadMoreErrorKey = nil

    async let wallet = loadWalletValue()
    async let initials = loadPlayerInitials()

    do {
      let page = try await feedRepository.load(
        count: Self.pageSize,
        forceRefresh: true,
        cursor: nil
      )
      try Task.checkCancellation()
      guard requestRevision == revision else { return }

      cards = Self.unique(page.challenges)
      milestone = page.milestone
      nextCursor = page.nextCursor
      phase = cards.isEmpty && nextCursor == nil ? .empty : .loaded
      generation += 1
    } catch is CancellationError {
      return
    } catch let error as AppError {
      guard requestRevision == revision else { return }
      phase = .failed(messageKey: error.messageKey)
    } catch {
      guard requestRevision == revision else { return }
      phase = .failed(messageKey: "something_wrong")
    }

    let supplemental = await (wallet, initials)
    guard requestRevision == revision else { return }
    if let coins = supplemental.0 { walletCoins = coins }
    playerInitials = supplemental.1
  }

  private func loadMore() async {
    guard
      phase == .loaded,
      !isLoadingMore,
      loadMoreErrorKey == nil,
      let cursor = nextCursor
    else {
      return
    }

    let requestRevision = revision
    isLoadingMore = true
    defer {
      if requestRevision == revision { isLoadingMore = false }
    }

    do {
      let page = try await feedRepository.load(
        count: Self.pageSize,
        forceRefresh: false,
        cursor: cursor
      )
      try Task.checkCancellation()
      guard requestRevision == revision else { return }
      guard page.nextCursor != cursor else {
        loadMoreErrorKey = "something_wrong"
        return
      }

      cards = Self.unique(cards + page.challenges)
      milestone = page.milestone ?? milestone
      nextCursor = page.nextCursor
    } catch is CancellationError {
      return
    } catch let error as AppError {
      guard requestRevision == revision else { return }
      loadMoreErrorKey = error.messageKey
    } catch {
      guard requestRevision == revision else { return }
      loadMoreErrorKey = "something_wrong"
    }
  }

  private func loadWalletValue() async -> Int? {
    try? await homeRepository.loadWallet(forceRefresh: true).coins
  }

  private func loadPlayerInitials() async -> String {
    guard let username = try? await tokenStore.loadSession()?.user.username else { return "P" }
    let initials =
      username
      .split(whereSeparator: \Character.isWhitespace)
      .prefix(2)
      .compactMap(\.first)
    return initials.isEmpty ? "P" : String(initials).uppercased()
  }

  private static func unique(_ challenges: [FeedChallenge]) -> [FeedChallenge] {
    var identifiers = Set<Int>()
    return challenges.filter { identifiers.insert($0.id).inserted }
  }
}
