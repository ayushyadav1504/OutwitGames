import SwiftUI

struct FeedView: View {
  private enum PageID: Hashable {
    case challenge(Int)
    case continuation
  }

  @Environment(\.scenePhase) private var scenePhase
  @State private var viewModel: FeedViewModel
  @State private var selectedPage: PageID?
  @State private var operationTask: Task<Void, Never>?

  init(
    feedRepository: any FeedRepository,
    homeRepository: any HomeRepository,
    tokenStore: any TokenStore,
    adGate: any FeedAdOpportunityReporting,
    coordinator: AppCoordinator
  ) {
    _viewModel = State(
      initialValue: FeedViewModel(
        feedRepository: feedRepository,
        homeRepository: homeRepository,
        tokenStore: tokenStore,
        adGate: adGate,
        coordinator: coordinator
      )
    )
  }

  var body: some View {
    Group {
      switch viewModel.phase {
      case .idle, .loading:
        FeedLoadingView()
      case .failed(let messageKey):
        FeedErrorView(messageKey: messageKey) { run { await viewModel.refresh() } }
      case .empty:
        FeedEndView { run { await viewModel.refresh() } }
      case .loaded:
        feedPager
      }
    }
    .background(OutwitColors.ink.ignoresSafeArea())
    .overlay(alignment: .top) {
      FeedHeader(
        coins: viewModel.walletCoins,
        playerInitials: viewModel.playerInitials,
        onCoinsTap: viewModel.openRewards,
        onProfileTap: viewModel.openProfile
      )
      .padding(.top, OutwitSpacing.x2)
    }
    .toolbar(.hidden, for: .navigationBar)
    .task { await viewModel.loadIfNeeded() }
    .onChange(of: viewModel.generation, initial: true) { _, _ in
      selectedPage = viewModel.cards.first.map { .challenge($0.id) } ?? .continuation
    }
    .onChange(of: selectedPage) { _, page in
      guard let page else { return }
      let index: Int
      switch page {
      case .challenge(let identifier):
        index = viewModel.cards.firstIndex { $0.id == identifier } ?? 0
      case .continuation:
        index = viewModel.cards.count
      }
      run { await viewModel.selectPage(at: index) }
    }
    .alert(
      "feed.unavailable.title",
      isPresented: unavailableAlertBinding,
      actions: { Button("common.ok", role: .cancel) {} },
      message: {
        if let key = viewModel.alertMessageKey {
          Text(LocalizedStringKey(key))
        }
      }
    )
    .onDisappear {
      operationTask?.cancel()
      operationTask = nil
      viewModel.cancel()
    }
  }

  private var feedPager: some View {
    ScrollView(.vertical) {
      LazyVStack(spacing: 0) {
        ForEach(viewModel.cards) { challenge in
          ChallengeCard(
            challenge: challenge,
            isActive: scenePhase == .active && selectedPage == .challenge(challenge.id),
            shouldPlaySwipeHint: viewModel.shouldPlaySwipeHint,
            onSwipeHintPlayed: viewModel.markSwipeHintPlayed,
            onStart: { viewModel.start(challenge) }
          )
          .containerRelativeFrame(.vertical)
          .id(PageID.challenge(challenge.id))
        }

        FeedContinuationView(
          isLoading: viewModel.isLoadingMore,
          errorKey: viewModel.loadMoreErrorKey,
          hasMore: viewModel.hasMore,
          onRetry: { run { await viewModel.retryContinuation() } },
          onRefresh: { run { await viewModel.refresh() } }
        )
        .containerRelativeFrame(.vertical)
        .id(PageID.continuation)
      }
      .scrollTargetLayout()
    }
    .scrollIndicators(.hidden)
    .scrollTargetBehavior(.paging)
    .scrollPosition(id: $selectedPage)
    .ignoresSafeArea()
    .accessibilityIdentifier("feed-pager")
  }

  private var unavailableAlertBinding: Binding<Bool> {
    Binding(
      get: { viewModel.alertMessageKey != nil },
      set: { if !$0 { viewModel.alertMessageKey = nil } }
    )
  }

  private func run(_ operation: @escaping @MainActor () async -> Void) {
    operationTask?.cancel()
    operationTask = Task { await operation() }
  }
}
