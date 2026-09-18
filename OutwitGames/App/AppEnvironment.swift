import Observation

/// The application composition root.
///
/// Shared dependencies are created here and injected into feature composition
/// boundaries. Feature views must not resolve global services themselves.
@MainActor
@Observable
final class AppEnvironment {
  let coordinator: AppCoordinator
  let settings: AppSettings

  init(settings: AppSettings = AppSettings(), coordinator: AppCoordinator? = nil) {
    self.settings = settings
    self.coordinator = coordinator ?? AppCoordinator(
      root: settings.language == nil ? .language : .onboarding
    )
  }
}
