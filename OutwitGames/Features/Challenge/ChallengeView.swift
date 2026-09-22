import SwiftUI

struct ChallengeView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var viewModel: ChallengeViewModel
  @State private var ownsOrientationLease = false

  private let hostOrigin: URL
  private let orientationController: any ChallengeOrientationControlling
  private let coordinator: AppCoordinator

  init(
    challenge: FeedChallenge,
    repository: any ChallengeRepository,
    rewardedAds: any RewardedAdServing,
    tokenStore: any TokenStore,
    analytics: any AnalyticsTracking,
    configuration: AppConfiguration,
    orientationController: any ChallengeOrientationControlling,
    coordinator: AppCoordinator
  ) {
    hostOrigin = configuration.webOrigin
    self.orientationController = orientationController
    self.coordinator = coordinator
    _viewModel = State(
      initialValue: ChallengeViewModel(
        repository: repository,
        rewardedAds: rewardedAds,
        tokenStore: tokenStore,
        analytics: analytics,
        coordinator: coordinator,
        challenge: challenge
      )
    )
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .preparing:
        ChallengePreparingView(
          title: viewModel.challenge.title,
          onCancel: viewModel.close
        )
      case .failed(let messageKey):
        ChallengeErrorView(
          messageKey: messageKey,
          onRetry: { Task { await viewModel.retryStart() } },
          onClose: viewModel.close
        )
      case .playing(let launch):
        gameplay(launch: launch, outcome: nil)
      case .result(let launch, let outcome):
        gameplay(launch: launch, outcome: outcome)
      }
    }
    .background(Color.black.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .navigationBarBackButtonHidden(true)
    .task { await viewModel.start() }
    .onAppear(perform: acquireOrientationLease)
    .onDisappear(perform: handleDisappearance)
    .alert(
      "challenge.exit.title",
      isPresented: exitPromptBinding,
      actions: {
        Button("challenge.exit.leave", role: .destructive, action: viewModel.close)
        Button("challenge.exit.stay", role: .cancel, action: viewModel.dismissExitPrompt)
      },
      message: { Text("challenge.exit.message") }
    )
    .alert(
      "challenge.reward.error.title",
      isPresented: actionErrorBinding,
      actions: {
        Button("common.ok", role: .cancel, action: viewModel.dismissActionError)
      },
      message: {
        if let key = viewModel.actionErrorKey {
          Text(LocalizedStringKey(key))
        }
      }
    )
  }

  private func gameplay(launch: ChallengeLaunch, outcome: ChallengeOutcome?) -> some View {
    VStack(spacing: 0) {
      if let hud = viewModel.hud {
        ChallengeHUDView(
          challengeTitle: viewModel.challenge.title,
          hud: hud,
          onClose: viewModel.requestExit
        )
      }

      ZStack {
        HostedGameView(
          launch: launch,
          hostOrigin: hostOrigin,
          isPaused: viewModel.shouldPauseGame || scenePhase != .active,
          onPageLoaded: viewModel.pageLoaded,
          onPageLoadFailed: viewModel.pageLoadFailed,
          onHUDEvent: viewModel.handle
        )
        .id(launch.gameID)

        if viewModel.isPageLoading {
          ZStack {
            Color.black
            ProgressView()
              .tint(.white)
              .controlSize(.large)
          }
          .accessibilityIdentifier("challenge-game-loading")
        }

        if let outcome {
          ChallengeResultView(
            launch: launch,
            outcome: outcome,
            multiplier: viewModel.multiplier,
            actionState: viewModel.resultActionState,
            onRetry: viewModel.retryWithRewardedAd,
            onMultiply: viewModel.multiplyReward,
            onContinue: viewModel.close,
            onWheelSettled: viewModel.multiplierDidSettle
          )
        }
      }
    }
    .ignoresSafeArea(edges: .bottom)
    .accessibilityIdentifier("challenge-gameplay")
  }

  private var exitPromptBinding: Binding<Bool> {
    Binding(
      get: { viewModel.isExitPromptVisible },
      set: { if !$0 { viewModel.dismissExitPrompt() } }
    )
  }

  private var actionErrorBinding: Binding<Bool> {
    Binding(
      get: { viewModel.actionErrorKey != nil },
      set: { if !$0 { viewModel.dismissActionError() } }
    )
  }

  private func acquireOrientationLease() {
    guard !ownsOrientationLease else { return }
    ownsOrientationLease = true
    orientationController.beginPortraitChallenge()
  }

  private func handleDisappearance() {
    Task { @MainActor in
      // A Google full-screen ad may temporarily cover this SwiftUI route and
      // trigger onDisappear. Yield so a real navigation pop can update the
      // coordinator, then cancel only when this challenge actually left it.
      await Task.yield()
      let currentRoute = coordinator.path.last ?? coordinator.root
      viewModel.routeDidDisappear(currentRoute: currentRoute)
      guard currentRoute != .challenge(viewModel.challenge), ownsOrientationLease else { return }
      ownsOrientationLease = false
      orientationController.endPortraitChallenge()
    }
  }
}
