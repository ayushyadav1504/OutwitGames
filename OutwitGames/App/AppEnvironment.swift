import Observation

/// The application composition root.
///
/// Shared dependencies are created here and injected into feature composition
/// boundaries. Feature views must not resolve global services themselves.
@MainActor
@Observable
final class AppEnvironment {
  let coordinator: AppCoordinator

  init(coordinator: AppCoordinator = AppCoordinator()) {
    self.coordinator = coordinator
  }
}
