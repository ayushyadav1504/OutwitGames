import Foundation
import Testing

@testable import OutwitGames

struct AuthRepositoryTests {
  @Test
  func guestVerificationUpgradesAndRefreshesTheStoredUser() async throws {
    let guestSession = Self.guestSession
    let upgradedUser = Self.registeredUser(id: 91, username: "upgrade-response")
    let refreshedUser = Self.registeredUser(id: 91, username: "refreshed-player")
    let store = InMemoryTokenStore(session: guestSession)
    let client = LoginAPIClient(
      upgradeResult: .success(upgradedUser),
      currentUserResult: .success(refreshedUser)
    )
    let repository = makeRepository(client: client, store: store)

    let user = try await repository.verifyOTP(phone: "9876543210", code: "2468")

    #expect(user == refreshedUser)
    #expect(await client.requestPaths == ["/upgrade/otp/verify", "/me"])
    #expect(await store.loadSession()?.user == refreshedUser)
    #expect(await store.loadSession()?.apiToken == guestSession.apiToken)
  }

  @Test
  func guestVerificationMapsPhoneTakenWithoutReplacingTheSession() async throws {
    let store = InMemoryTokenStore(session: Self.guestSession)
    let client = LoginAPIClient(
      upgradeResult: .failure(.validation(messageKey: "phone_taken"))
    )
    let repository = makeRepository(client: client, store: store)

    do {
      _ = try await repository.verifyOTP(phone: "9876543210", code: "2468")
      Issue.record("Expected the phone-already-registered branch")
    } catch let error as AuthenticationError {
      #expect(error == .phoneAlreadyRegistered)
    }

    #expect(await client.requestPaths == ["/upgrade/otp/verify"])
    #expect(await store.loadSession() == Self.guestSession)
  }

  @Test
  func existingAccountLoginReplacesTheGuestSession() async throws {
    let registeredSession = Self.registeredSession
    let store = InMemoryTokenStore(session: Self.guestSession)
    let client = LoginAPIClient(
      verifyResult: .success(registeredSession),
      currentUserResult: .failure(.server())
    )
    let repository = makeRepository(client: client, store: store)

    let user = try await repository.loginToExistingAccount(
      phone: "9876543210",
      code: "2468"
    )

    #expect(user == registeredSession.user)
    #expect(await client.requestPaths == ["/auth/otp/verify", "/me"])
    #expect(await store.loadSession() == registeredSession)
  }

  @Test
  func registeredSessionUsesTheFullOTPLoginEndpoint() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let client = LoginAPIClient(
      verifyResult: .success(Self.registeredSession),
      currentUserResult: .failure(.server())
    )
    let repository = makeRepository(client: client, store: store)

    _ = try await repository.verifyOTP(phone: "9876543210", code: "2468")

    #expect(await client.requestPaths == ["/auth/otp/verify", "/me"])
    #expect(await store.loadSession() == Self.registeredSession)
  }

  @Test
  func incompleteOTPResponseIsRejectedWithoutReplacingTheSession() async throws {
    let incomplete = AuthSession(
      user: Self.registeredUser(id: 91, username: "player"),
      apiToken: "",
      socketToken: "socket",
      refreshToken: "refresh"
    )
    let store = InMemoryTokenStore(session: TestSessions.original)
    let client = LoginAPIClient(verifyResult: .success(incomplete))
    let repository = makeRepository(client: client, store: store)

    do {
      _ = try await repository.loginToExistingAccount(phone: "9876543210", code: "2468")
      Issue.record("Expected an incomplete session to fail")
    } catch let error as AppError {
      #expect(error == .parsing)
    }

    #expect(await store.loadSession() == TestSessions.original)
  }

  @Test
  func signOutClearsTheLocalSessionWithoutCallingTheBackend() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let client = LoginAPIClient()
    let repository = makeRepository(client: client, store: store)

    try await repository.signOut()

    #expect(await store.loadSession() == nil)
    #expect(await client.requestPaths.isEmpty)
  }

  @Test
  func accountDeletionClearsTheSessionOnlyAfterBackendSuccess() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let client = LoginAPIClient(deleteResult: .success(()))
    let repository = makeRepository(client: client, store: store)

    try await repository.deleteAccount()

    #expect(await client.requestPaths == ["/account"])
    #expect(await store.loadSession() == nil)
  }

  @Test
  func deleteAccountRequestValidatesTheBackendStatus() throws {
    let request = DeleteAccountRequest.make()

    #expect(request.path == "/account")
    #expect(request.method == .delete)
    #expect(request.requiresAuthentication)
    try request.decodeResponse(from: Data(#"{"status":"deletion_scheduled"}"#.utf8))
    #expect(throws: AppError.parsing) {
      try request.decodeResponse(from: Data(#"{"status":"unexpected"}"#.utf8))
    }
  }

  private func makeRepository(
    client: LoginAPIClient,
    store: InMemoryTokenStore
  ) -> DefaultAuthRepository {
    DefaultAuthRepository(apiClient: client, tokenStore: store, device: Self.device)
  }

  private static func registeredUser(id: Int, username: String) -> AuthUser {
    AuthUser(
      id: id,
      kind: "registered",
      username: username,
      phone: "+919876543210",
      externalID: "external-\(id)"
    )
  }

  private static let guestSession = AuthSession(
    user: AuthUser(
      id: 71,
      kind: "guest",
      username: "guest-71",
      phone: "",
      externalID: ""
    ),
    apiToken: "guest-api",
    socketToken: "guest-socket",
    refreshToken: "guest-refresh"
  )

  private static let registeredSession = AuthSession(
    user: registeredUser(id: 91, username: "registered-player"),
    apiToken: "registered-api",
    socketToken: "registered-socket",
    refreshToken: "registered-refresh"
  )

  private static let device = DeviceSnapshot(
    id: "ios-device",
    appVersion: "1.0.0",
    appBuild: "8",
    deviceModel: "iPhone",
    osName: "iOS",
    osVersion: "17.0",
    platform: "ios"
  )
}

private actor LoginAPIClient: APIClient {
  private let upgradeResult: Result<AuthUser, AppError>
  private let verifyResult: Result<AuthSession, AppError>
  private let currentUserResult: Result<AuthUser, AppError>
  private let deleteResult: Result<Void, AppError>
  private(set) var requestPaths: [String] = []

  init(
    upgradeResult: Result<AuthUser, AppError> = .failure(.parsing),
    verifyResult: Result<AuthSession, AppError> = .failure(.parsing),
    currentUserResult: Result<AuthUser, AppError> = .failure(.parsing),
    deleteResult: Result<Void, AppError> = .failure(.parsing)
  ) {
    self.upgradeResult = upgradeResult
    self.verifyResult = verifyResult
    self.currentUserResult = currentUserResult
    self.deleteResult = deleteResult
  }

  func send<Response: Sendable>(_ request: APIRequest<Response>) async throws -> Response {
    requestPaths.append(request.path)
    let value: Any

    switch request.path {
    case "/auth/otp/request":
      value = ()
    case "/upgrade/otp/verify":
      value = try upgradeResult.get()
    case "/auth/otp/verify":
      value = try verifyResult.get()
    case "/me":
      value = try currentUserResult.get()
    case "/account":
      value = try deleteResult.get()
    default:
      throw AppError.invalidRequest
    }

    guard let response = value as? Response else { throw AppError.parsing }
    return response
  }
}
