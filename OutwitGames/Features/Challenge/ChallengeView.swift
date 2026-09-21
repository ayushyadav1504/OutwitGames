import SwiftUI

struct ChallengeView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var viewModel: ChallengeViewModel

  private let hostOrigin: URL
  private let orientationController: any ChallengeOrientationControlling

  init(
    challenge: FeedChallenge,
    repository: any ChallengeRepository,
    configuration: AppConfiguration,
    orientationController: any ChallengeOrientationControlling,
    coordinator: AppCoordinator
  ) {
    hostOrigin = configuration.webOrigin
    self.orientationController = orientationController
    _viewModel = State(
      initialValue: ChallengeViewModel(
        repository: repository,
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
          onRetry: { Task { await viewModel.retry() } },
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
    .onAppear { orientationController.beginPortraitChallenge() }
    .onDisappear {
      viewModel.cancel()
      orientationController.endPortraitChallenge()
    }
    .alert(
      "challenge.exit.title",
      isPresented: exitPromptBinding,
      actions: {
        Button("challenge.exit.leave", role: .destructive, action: viewModel.close)
        Button("challenge.exit.stay", role: .cancel, action: viewModel.dismissExitPrompt)
      },
      message: { Text("challenge.exit.message") }
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
          ChallengeResultView(outcome: outcome, onContinue: viewModel.close)
        }
      }
    }
    .ignoresSafeArea(edges: .bottom)
  }

  private var exitPromptBinding: Binding<Bool> {
    Binding(
      get: { viewModel.isExitPromptVisible },
      set: { if !$0 { viewModel.dismissExitPrompt() } }
    )
  }
}
