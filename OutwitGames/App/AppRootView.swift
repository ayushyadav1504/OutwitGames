import SwiftUI

struct AppRootView: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    @Bindable var coordinator = environment.coordinator

    NavigationStack(path: $coordinator.path) {
      routeView(for: coordinator.root)
        .navigationDestination(for: AppRoute.self) { route in
          routeView(for: route)
        }
    }
    .sheet(item: $coordinator.sheet) { sheet in
      switch sheet {
      case .profile:
        PendingFeatureView(title: "screen.profile.title")
      case .notificationSoftAsk:
        PendingFeatureView(title: "screen.notifications.title")
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
      PendingFeatureView(title: "screen.login.title")
    case .feed:
      PendingFeatureView(title: "screen.feed.title")
    case .rewards:
      PendingFeatureView(title: "screen.rewards.title")
    }
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
  }
}

#Preview {
  AppRootView()
    .environment(AppEnvironment())
}
