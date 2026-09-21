import SwiftUI

struct AppRootView: View {
  @Environment(AppEnvironment.self) private var environment
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    @Bindable var coordinator = environment.coordinator

    NavigationStack(path: $coordinator.path) {
      routeView(for: coordinator.root)
        .navigationDestination(for: AppRoute.self) { route in
          routeView(for: route)
        }
    }
    .id(coordinator.rootRevision)
    .sheet(item: $coordinator.sheet) { sheet in
      switch sheet {
      case .profile:
        PendingFeatureView(title: "screen.profile.title")
      case .notificationSoftAsk:
        PendingFeatureView(title: "screen.notifications.title")
      }
    }
    .task {
      await environment.socketSession.start()
      await environment.socketSession.setForeground(
        AppSocketLifecyclePolicy.keepsConnection(for: scenePhase)
      )
    }
    .onChange(of: scenePhase) { _, phase in
      Task {
        await environment.socketSession.setForeground(
          AppSocketLifecyclePolicy.keepsConnection(for: phase)
        )
      }
    }
  }

  @ViewBuilder
  private func routeView(for route: AppRoute) -> some View {
    switch route {
    case .splash:
      StartupView(
        sessionBootstrapper: environment.sessionBootstrapper,
        settings: environment.settings,
        coordinator: environment.coordinator
      )
    case .language:
      LanguageView(settings: environment.settings, coordinator: environment.coordinator)
    case .onboarding:
      OnboardingView(
        settings: environment.settings,
        notifications: environment.notificationPermissionRequester,
        coordinator: environment.coordinator
      )
    case .login:
      LoginView(
        authRepository: environment.authRepository,
        coordinator: environment.coordinator
      )
    case .feed:
      FeedView(
        feedRepository: environment.feedRepository,
        homeRepository: environment.homeRepository,
        tokenStore: environment.tokenStore,
        coordinator: environment.coordinator
      )
    case .rewards:
      PendingFeatureView(title: "screen.rewards.title")
    case .challenge(let challenge):
      ChallengeView(
        challenge: challenge,
        repository: environment.challengeRepository,
        configuration: environment.configuration,
        orientationController: environment.challengeOrientationController,
        coordinator: environment.coordinator
      )
    }
  }
}

nonisolated enum AppSocketLifecyclePolicy {
  static func keepsConnection(for phase: ScenePhase) -> Bool {
    phase != .background
  }
}

private struct PendingFeatureView: View {
  let title: LocalizedStringKey

  var body: some View {
    ContentUnavailableView(
      title,
      systemImage: "hammer",
      description: Text("screen.pending.description")
    )
    .accessibilityIdentifier("pending-feature")
  }
}

#Preview {
  AppRootView()
    .environment(AppEnvironment())
}
