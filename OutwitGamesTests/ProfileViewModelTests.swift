import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct ProfileViewModelTests {
  @Test
  func registeredProfileLoadsIdentityAndSignOutReturnsToSplash() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }

    await context.viewModel.load()

    #expect(
      context.viewModel.state
        == .loaded(
          ProfileIdentity(
            name: "player",
            phone: "+91 0000000000",
            isRegistered: true
          )
        )
    )

    await context.viewModel.signOut()

    #expect(await context.auth.signOutCount == 1)
    #expect(context.coordinator.root == .splash)
    #expect(context.coordinator.sheet == nil)
  }

  @Test
  func deletionRequiresTheExactConfirmationBeforeCallingTheRepository() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    await context.viewModel.load()

    context.viewModel.requestAccountDeletion()
    await context.viewModel.confirmAccountDeletion(confirmation: "delete")

    #expect(await context.auth.deleteCount == 0)
    #expect(context.coordinator.root == .feed)

    await context.viewModel.confirmAccountDeletion(confirmation: " DELETE ")

    #expect(await context.auth.deleteCount == 1)
    #expect(context.coordinator.root == .splash)
  }

  @Test
  func deniedNotificationPermissionOpensSettingsInsteadOfPromptingAgain() async throws {
    let notifications = ProfileNotificationStub(state: .denied)
    let context = try makeContext(notifications: notifications)
    defer { context.cleanUp() }
    await context.viewModel.load()

    await context.viewModel.performNotificationAction()

    #expect(await notifications.openSettingsCount == 1)
    #expect(await notifications.requestCount == 0)
  }

  private func makeContext(
    notifications: ProfileNotificationStub = ProfileNotificationStub(state: .authorized)
  ) throws -> ProfileTestContext {
    let suiteName = "ProfileViewModelTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let coordinator = AppCoordinator(root: .feed)
    coordinator.present(.profile)
    let auth = ProfileAuthRepositorySpy()
    let viewModel = ProfileViewModel(
      settings: AppSettings(defaults: defaults),
      tokenStore: InMemoryTokenStore(session: TestSessions.original),
      authRepository: auth,
      notifications: notifications,
      consent: ProfileConsentStub(),
      analytics: NoOpAnalyticsTracker(),
      configuration: .development,
      coordinator: coordinator
    )
    return ProfileTestContext(
      viewModel: viewModel,
      auth: auth,
      coordinator: coordinator,
      defaults: defaults,
      suiteName: suiteName
    )
  }
}

private struct ProfileTestContext {
  let viewModel: ProfileViewModel
  let auth: ProfileAuthRepositorySpy
  let coordinator: AppCoordinator
  let defaults: UserDefaults
  let suiteName: String

  func cleanUp() {
    defaults.removePersistentDomain(forName: suiteName)
  }
}

private actor ProfileAuthRepositorySpy: AuthRepository {
  private(set) var signOutCount = 0
  private(set) var deleteCount = 0

  func sendOTP(to nationalPhoneNumber: String) async throws {}

  func verifyOTP(phone: String, code: String) async throws -> AuthUser {
    throw AppError.invalidRequest
  }

  func loginToExistingAccount(phone: String, code: String) async throws -> AuthUser {
    throw AppError.invalidRequest
  }

  func signOut() {
    signOutCount += 1
  }

  func deleteAccount() {
    deleteCount += 1
  }
}

private actor ProfileNotificationStub: NotificationPermissionRequesting {
  private let state: NotificationAuthorizationState
  private(set) var requestCount = 0
  private(set) var openSettingsCount = 0

  init(state: NotificationAuthorizationState) {
    self.state = state
  }

  func authorizationState() -> NotificationAuthorizationState {
    state
  }

  func requestAuthorization() -> Bool {
    requestCount += 1
    return state == .authorized
  }

  func openSettings() {
    openSettingsCount += 1
  }
}

@MainActor
private final class ProfileConsentStub: AdConsentServicing {
  let canRequestAds = true
  let isPrivacyOptionsRequired = false

  func prepare() async {}
  func presentPrivacyOptions() async throws {}
}
