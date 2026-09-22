import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct OnboardingViewModelTests {
  @Test
  func resumesAtNotificationAskAfterTutorialWasSeen() throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    context.settings.markIntroductionSeen()

    let viewModel = OnboardingViewModel(
      settings: context.settings,
      notifications: NotificationRequesterStub(result: .success(true)),
      coordinator: context.coordinator
    )

    #expect(viewModel.step == .notifications)
  }

  @Test
  func finalTutorialActionPersistsProgressWithoutCompletingOnboarding() throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    let viewModel = OnboardingViewModel(
      settings: context.settings,
      notifications: NotificationRequesterStub(result: .success(true)),
      coordinator: context.coordinator
    )

    viewModel.selectTutorialPage(2)
    viewModel.advanceTutorial()

    #expect(viewModel.step == .notifications)
    #expect(context.settings.hasSeenIntroduction)
    #expect(!context.settings.isOnboardingComplete)
    #expect(context.coordinator.root == .onboarding)
  }

  @Test
  func permissionActionRequestsAccessAndCompletesOnboarding() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    let notifications = NotificationRequesterStub(result: .success(false))
    let viewModel = OnboardingViewModel(
      settings: context.settings,
      notifications: notifications,
      coordinator: context.coordinator
    )

    viewModel.selectTutorialPage(2)
    viewModel.advanceTutorial()
    await viewModel.turnOnNotifications()

    #expect(await notifications.requestCount == 1)
    #expect(context.settings.hasSeenIntroduction)
    #expect(context.settings.isOnboardingComplete)
    #expect(context.coordinator.root == .feed)
  }

  @Test
  func notificationErrorDoesNotTrapUserInOnboarding() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    let viewModel = OnboardingViewModel(
      settings: context.settings,
      notifications: NotificationRequesterStub(result: .failure(.unavailable)),
      coordinator: context.coordinator
    )

    viewModel.selectTutorialPage(2)
    viewModel.advanceTutorial()
    await viewModel.turnOnNotifications()

    #expect(context.settings.isOnboardingComplete)
    #expect(context.coordinator.root == .feed)
  }

  @Test
  func notNowCompletesWithoutRequestingPermission() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    let notifications = NotificationRequesterStub(result: .success(true))
    let viewModel = OnboardingViewModel(
      settings: context.settings,
      notifications: notifications,
      coordinator: context.coordinator
    )

    viewModel.selectTutorialPage(2)
    viewModel.advanceTutorial()
    viewModel.skipNotifications()

    #expect(await notifications.requestCount == 0)
    #expect(context.settings.isOnboardingComplete)
    #expect(context.coordinator.root == .feed)
  }

  private func makeContext() throws -> OnboardingTestContext {
    let suiteName = "OnboardingViewModelTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return OnboardingTestContext(
      settings: AppSettings(defaults: defaults),
      coordinator: AppCoordinator(root: .onboarding),
      defaults: defaults,
      suiteName: suiteName
    )
  }
}

private struct OnboardingTestContext {
  let settings: AppSettings
  let coordinator: AppCoordinator
  let defaults: UserDefaults
  let suiteName: String

  func cleanUp() {
    defaults.removePersistentDomain(forName: suiteName)
  }
}

private actor NotificationRequesterStub: NotificationPermissionRequesting {
  private let result: Result<Bool, NotificationTestError>
  private(set) var requestCount = 0

  init(result: Result<Bool, NotificationTestError>) {
    self.result = result
  }

  func authorizationState() -> NotificationAuthorizationState {
    .notDetermined
  }

  func requestAuthorization() async throws -> Bool {
    requestCount += 1
    return try result.get()
  }

  func openSettings() {}
}

private enum NotificationTestError: Error {
  case unavailable
}
