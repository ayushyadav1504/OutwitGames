import Foundation

nonisolated protocol AuthRepository: Sendable {
  func sendOTP(to nationalPhoneNumber: String) async throws
  func verifyOTP(phone: String, code: String) async throws -> AuthUser
  func loginToExistingAccount(phone: String, code: String) async throws -> AuthUser
}

nonisolated struct DefaultAuthRepository: AuthRepository {
  private let apiClient: any APIClient
  private let tokenStore: any TokenStore
  private let device: DeviceSnapshot

  init(
    apiClient: any APIClient,
    tokenStore: any TokenStore,
    device: DeviceSnapshot
  ) {
    self.apiClient = apiClient
    self.tokenStore = tokenStore
    self.device = device
  }

  func sendOTP(to nationalPhoneNumber: String) async throws {
    try await apiClient.send(
      SendOTPRequest.make(phone: indiaE164(nationalPhoneNumber))
    )
  }

  func verifyOTP(phone: String, code: String) async throws -> AuthUser {
    let e164Phone = indiaE164(phone)
    let currentUser = try await tokenStore.loadSession()?.user

    if currentUser?.kind == "guest" {
      return try await upgradeGuest(phone: e164Phone, code: code)
    }

    return try await loginWithOTP(phone: e164Phone, code: code)
  }

  func loginToExistingAccount(phone: String, code: String) async throws -> AuthUser {
    // Account-scoped feature stores are introduced with their owning features.
    // The complete session replacement below prevents the guest credentials
    // from surviving this account switch.
    try await loginWithOTP(phone: indiaE164(phone), code: code)
  }

  private func upgradeGuest(phone: String, code: String) async throws -> AuthUser {
    let user: AuthUser
    do {
      user = try await apiClient.send(
        try UpgradeGuestRequest.make(phone: phone, code: code)
      )
    } catch AppError.validation(let messageKey) where messageKey == "phone_taken" {
      throw AuthenticationError.phoneAlreadyRegistered
    }

    guard user.isRegistered else { throw AppError.parsing }
    try await tokenStore.saveUser(user)
    return try await refreshCurrentUser(fallback: user)
  }

  private func loginWithOTP(phone: String, code: String) async throws -> AuthUser {
    let session = try await apiClient.send(
      try VerifyOTPRequest.make(
        phone: phone,
        code: code,
        device: device
      )
    )
    guard session.isComplete, session.user.isRegistered else {
      throw AppError.parsing
    }

    try await tokenStore.saveSession(session)
    return try await refreshCurrentUser(fallback: session.user)
  }

  private func refreshCurrentUser(fallback: AuthUser) async throws -> AuthUser {
    let user: AuthUser
    do {
      user = try await apiClient.send(CurrentUserRequest.make())
    } catch is CancellationError {
      throw CancellationError()
    } catch is AppError {
      return fallback
    }

    try await tokenStore.saveUser(user)
    return user
  }

  private func indiaE164(_ nationalPhoneNumber: String) -> String {
    "+91\(nationalPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines))"
  }
}
