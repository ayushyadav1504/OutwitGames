nonisolated protocol SessionBootstrapping: Sendable {
  func establishSession() async throws -> Bool
}

nonisolated struct SessionBootstrapper: SessionBootstrapping {
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

  func establishSession() async throws -> Bool {
    guard try await tokenStore.hasSession() else {
      return try await loginAsGuest()
    }

    do {
      let user = try await apiClient.send(CurrentUserRequest.make())
      try await tokenStore.saveUser(user)
      return true
    } catch is CancellationError {
      throw CancellationError()
    } catch is AppError {
      if try await tokenStore.hasSession() {
        return false
      }
      return try await loginAsGuest()
    }
  }

  private func loginAsGuest() async throws -> Bool {
    do {
      let request = try GuestLoginRequest.make(device: device)
      let session = try await apiClient.send(request)
      guard session.isComplete else { throw AppError.parsing }
      try await tokenStore.saveSession(session)
      return true
    } catch is CancellationError {
      throw CancellationError()
    } catch is AppError {
      return false
    }
  }
}
