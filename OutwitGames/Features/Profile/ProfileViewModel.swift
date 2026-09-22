import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
  private let settings: AppSettings
  private let tokenStore: any TokenStore
  private let authRepository: any AuthRepository
  private let notifications: any NotificationPermissionRequesting
  private let consent: any AdConsentServicing
  private let analytics: any AnalyticsTracking
  private let coordinator: AppCoordinator

  let privacyPolicyURL: URL
  let termsAndConditionsURL: URL

  private(set) var state = ProfileScreenState.idle
  private(set) var selectedLanguage: AppLanguage
  private(set) var notificationState: NotificationAuthorizationState?
  private(set) var isRequestingNotifications = false
  private(set) var operation = ProfileOperationState.idle
  private(set) var isDeleteConfirmationPresented = false
  private(set) var privacyOptionsRequired = false
  private(set) var actionErrorKey: String?

  init(
    settings: AppSettings,
    tokenStore: any TokenStore,
    authRepository: any AuthRepository,
    notifications: any NotificationPermissionRequesting,
    consent: any AdConsentServicing,
    analytics: any AnalyticsTracking,
    configuration: AppConfiguration,
    coordinator: AppCoordinator
  ) {
    self.settings = settings
    self.tokenStore = tokenStore
    self.authRepository = authRepository
    self.notifications = notifications
    self.consent = consent
    self.analytics = analytics
    self.coordinator = coordinator
    selectedLanguage = settings.language ?? .english
    privacyPolicyURL = configuration.privacyPolicyURL
    termsAndConditionsURL = configuration.termsAndConditionsURL
  }

  func load() async {
    guard state == .idle || isFailed else { return }
    state = .loading
    privacyOptionsRequired = consent.isPrivacyOptionsRequired

    async let authorizationState = notifications.authorizationState()
    do {
      guard let user = try await tokenStore.loadSession()?.user else {
        throw AppError.unauthorized()
      }
      notificationState = await authorizationState
      state = .loaded(
        ProfileIdentity(
          name: user.username.trimmingCharacters(in: .whitespacesAndNewlines),
          phone: Self.displayPhone(user.phone),
          isRegistered: user.isRegistered
        )
      )
    } catch is CancellationError {
      state = .idle
    } catch {
      _ = await authorizationState
      state = .failed(messageKey: Self.messageKey(for: error))
    }
  }

  func refreshNotificationState() async {
    notificationState = await notifications.authorizationState()
  }

  func performNotificationAction() async {
    guard !isRequestingNotifications else { return }
    if notificationState == .denied {
      await notifications.openSettings()
      return
    }

    isRequestingNotifications = true
    defer { isRequestingNotifications = false }
    do {
      let granted = try await notifications.requestAuthorization()
      let refreshedState = await notifications.authorizationState()
      notificationState = granted ? .authorized : refreshedState
      if notificationState == .authorized {
        await analytics.track(.notificationPermissionGiven(source: "Profiles"))
      }
    } catch is CancellationError {
      return
    } catch {
      actionErrorKey = Self.messageKey(for: error)
    }
  }

  func selectLanguage(_ language: AppLanguage) {
    guard selectedLanguage != language else { return }
    selectedLanguage = language
    settings.setLanguage(language)
    Task { [analytics] in
      await analytics.track(.languageSelected(language, source: "Profiles"))
    }
  }

  func openLogin() {
    Task { [analytics] in
      await analytics.track(.loginInitiated(source: "Profile"))
    }
    coordinator.openLoginFromProfile()
  }

  func signOut() async {
    guard operation == .idle else { return }
    operation = .signingOut
    actionErrorKey = nil
    await analytics.track(.logoutDone())

    do {
      try await authRepository.signOut()
      operation = .idle
      coordinator.restartAfterAccountExit()
    } catch is CancellationError {
      operation = .idle
    } catch {
      operation = .idle
      actionErrorKey = Self.messageKey(for: error)
    }
  }

  func requestAccountDeletion() {
    guard operation == .idle else { return }
    isDeleteConfirmationPresented = true
  }

  func cancelAccountDeletion() {
    isDeleteConfirmationPresented = false
  }

  func confirmAccountDeletion(confirmation: String) async {
    guard
      operation == .idle,
      confirmation.trimmingCharacters(in: .whitespacesAndNewlines) == "DELETE"
    else {
      return
    }
    isDeleteConfirmationPresented = false
    operation = .deletingAccount
    actionErrorKey = nil

    do {
      try await authRepository.deleteAccount()
      operation = .idle
      coordinator.restartAfterAccountExit()
    } catch is CancellationError {
      operation = .idle
    } catch {
      operation = .idle
      actionErrorKey = Self.messageKey(for: error)
    }
  }

  func presentPrivacyOptions() async {
    do {
      try await consent.presentPrivacyOptions()
      privacyOptionsRequired = consent.isPrivacyOptionsRequired
    } catch is CancellationError {
      return
    } catch {
      actionErrorKey = Self.messageKey(for: error)
    }
  }

  func dismissError() {
    actionErrorKey = nil
  }

  var showsNotificationSetting: Bool {
    notificationState != .authorized
  }

  var isBusy: Bool {
    operation != .idle
  }

  private var isFailed: Bool {
    if case .failed = state { return true }
    return false
  }

  private static func displayPhone(_ phone: String) -> String {
    let value = phone.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.hasPrefix("+91"), value.count > 3 else { return value }
    return "+91 \(value.dropFirst(3))"
  }

  private static func messageKey(for error: any Error) -> String {
    (error as? AppError)?.messageKey ?? AppError.server().messageKey
  }
}
