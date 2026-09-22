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
        ProfilePlaceholderView(consent: environment.adConsentService)
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
    .task {
      await environment.adConsentService.prepare()
      await environment.rewardedAdService.initialize()
      environment.feedAdScheduler.start()
    }
    .onChange(of: feedAdSessionState, initial: true) { _, state in
      environment.feedAdScheduler.update(state)
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
        adGate: environment.feedAdScheduler,
        coordinator: environment.coordinator
      )
    case .rewards(let source):
      RewardsView(
        rewardsRepository: environment.rewardsRepository,
        referralsRepository: environment.referralsRepository,
        homeRepository: environment.homeRepository,
        tokenStore: environment.tokenStore,
        analytics: environment.analytics,
        coordinator: environment.coordinator,
        entrySource: source
      )
    case .challenge(let challenge):
      ChallengeView(
        challenge: challenge,
        repository: environment.challengeRepository,
        rewardedAds: environment.rewardedAdService,
        tokenStore: environment.tokenStore,
        analytics: environment.analytics,
        configuration: environment.configuration,
        orientationController: environment.challengeOrientationController,
        coordinator: environment.coordinator
      )
      .id(challenge.id)
    }
  }

  private var feedAdSessionState: FeedAdSessionState {
    let route = environment.coordinator.path.last ?? environment.coordinator.root
    let isForeground = scenePhase == .active
    let counts: Bool
    let isInChallenge: Bool
    switch route {
    case .feed, .rewards:
      counts = isForeground
      isInChallenge = false
    case .challenge:
      counts = false
      isInChallenge = true
    default:
      counts = false
      isInChallenge = false
    }
    return FeedAdSessionState(
      counts: counts,
      showable: isForeground && route == .feed && environment.coordinator.sheet == nil,
      isInChallenge: isInChallenge,
      sessionRevision: environment.coordinator.rootRevision
    )
  }
}

private struct ProfilePlaceholderView: View {
  let consent: any AdConsentServicing
  @State private var privacyOptionsRequired = false

  var body: some View {
    VStack(spacing: OutwitSpacing.x4) {
      ContentUnavailableView(
        "screen.profile.title",
        systemImage: "person.crop.circle",
        description: Text("screen.pending.description")
      )
      if privacyOptionsRequired {
        Button("privacy.options") {
          Task { try? await consent.presentPrivacyOptions() }
        }
        .buttonStyle(.outwitPrimary)
        .frame(maxWidth: 320)
      }
    }
    .padding(OutwitSpacing.pageGutter)
    .task { privacyOptionsRequired = consent.isPrivacyOptionsRequired }
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
