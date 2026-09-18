import Observation

enum StartupState: Equatable, Sendable {
  case loading
  case failed
}

@MainActor
@Observable
final class StartupViewModel {
  private let sessionBootstrapper: any SessionBootstrapping
  private let settings: AppSettings
  private let coordinator: AppCoordinator
  private let minimumDisplayDuration: Duration

  private var hasStarted = false
  private var isRunning = false

  private(set) var state = StartupState.loading

  init(
    sessionBootstrapper: any SessionBootstrapping,
    settings: AppSettings,
    coordinator: AppCoordinator,
    minimumDisplayDuration: Duration = .seconds(2.4)
  ) {
    self.sessionBootstrapper = sessionBootstrapper
    self.settings = settings
    self.coordinator = coordinator
    self.minimumDisplayDuration = minimumDisplayDuration
  }

  func start() async {
    guard !hasStarted else { return }
    hasStarted = true
    await bootstrap()
  }

  func retry() async {
    guard state == .failed else { return }
    await bootstrap()
  }

  private func bootstrap() async {
    guard !isRunning else { return }
    isRunning = true
    state = .loading
    defer { isRunning = false }

    do {
      async let established = sessionBootstrapper.establishSession()
      try await ContinuousClock().sleep(for: minimumDisplayDuration)
      guard try await established else {
        state = .failed
        return
      }
      routeToFirstRequiredScreen()
    } catch is CancellationError {
      return
    } catch {
      state = .failed
    }
  }

  private func routeToFirstRequiredScreen() {
    if settings.language == nil {
      coordinator.reset(to: .language)
    } else if !settings.isOnboardingComplete {
      coordinator.reset(to: .onboarding)
    } else {
      coordinator.reset(to: .feed)
    }
  }
}
