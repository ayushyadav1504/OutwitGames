import Observation

enum OnboardingStep: Equatable, Sendable {
  case tutorial(page: Int)
  case notifications
}

@MainActor
@Observable
final class OnboardingViewModel {
  static let tutorialPageCount = 3

  private let settings: AppSettings
  private let notifications: any NotificationPermissionRequesting
  private let coordinator: AppCoordinator

  private(set) var step: OnboardingStep
  private(set) var isBusy = false

  init(
    settings: AppSettings,
    notifications: any NotificationPermissionRequesting,
    coordinator: AppCoordinator
  ) {
    self.settings = settings
    self.notifications = notifications
    self.coordinator = coordinator
    step = settings.hasSeenIntroduction ? .notifications : .tutorial(page: 0)
  }

  var tutorialPage: Int {
    guard case .tutorial(let page) = step else { return 0 }
    return page
  }

  func selectTutorialPage(_ page: Int) {
    guard case .tutorial = step else { return }
    let lastPage = Self.tutorialPageCount - 1
    step = .tutorial(page: min(max(page, 0), lastPage))
  }

  func advanceTutorial() {
    guard case .tutorial(let page) = step, !isBusy else { return }
    if page < Self.tutorialPageCount - 1 {
      step = .tutorial(page: page + 1)
    } else {
      settings.markIntroductionSeen()
      step = .notifications
    }
  }

  func turnOnNotifications() async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }

    do {
      _ = try await notifications.requestAuthorization()
      try Task.checkCancellation()
      completeOnboarding()
    } catch is CancellationError {
      return
    } catch {
      completeOnboarding()
    }
  }

  func skipNotifications() {
    guard !isBusy else { return }
    completeOnboarding()
  }

  private func completeOnboarding() {
    settings.markIntroductionSeen()
    settings.markOnboardingComplete()
    coordinator.reset(to: .feed)
  }
}
