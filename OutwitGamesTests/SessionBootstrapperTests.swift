import Testing

@testable import OutwitGames

struct SessionBootstrapperTests {
  @Test
  func createsAndPersistsGuestWhenNoSessionExists() async throws {
    let store = InMemoryTokenStore()
    let client = BootstrapAPIClient(guestResult: .success(Self.guestSession))
    let bootstrapper = SessionBootstrapper(
      apiClient: client,
      tokenStore: store,
      device: Self.device
    )

    #expect(try await bootstrapper.establishSession())
    #expect(await store.loadSession() == Self.guestSession)
    #expect(await client.requestPaths == ["/auth/guest"])
  }

  @Test
  func refreshesStoredUserWhenSessionExists() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let refreshedUser = AuthUser(
      id: 42,
      kind: "registered",
      username: "updated-player",
      phone: "+919999999999",
      externalID: "external-42"
    )
    let client = BootstrapAPIClient(currentUserResult: .success(refreshedUser))
    let bootstrapper = SessionBootstrapper(
      apiClient: client,
      tokenStore: store,
      device: Self.device
    )

    #expect(try await bootstrapper.establishSession())
    #expect(await store.loadSession()?.user == refreshedUser)
    #expect(await client.requestPaths == ["/me"])
  }

  @Test
  func keepsExistingSessionAndReportsRetryableFailure() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let client = BootstrapAPIClient(currentUserResult: .failure(.server()))
    let bootstrapper = SessionBootstrapper(
      apiClient: client,
      tokenStore: store,
      device: Self.device
    )

    #expect(try await bootstrapper.establishSession() == false)
    #expect(await store.loadSession() == TestSessions.original)
    #expect(await client.requestPaths == ["/me"])
  }

  private static let device = DeviceSnapshot(
    id: "device-1",
    appVersion: "1.0.0",
    appBuild: "1",
    deviceModel: "iPhone",
    osName: "iOS",
    osVersion: "17.0",
    platform: "ios"
  )

  private static let guestSession = AuthSession(
    user: AuthUser(
      id: 71,
      kind: "guest",
      username: "guest-71",
      phone: "",
      externalID: ""
    ),
    apiToken: "guest-api-token",
    socketToken: "guest-socket-token",
    refreshToken: "guest-refresh-token"
  )
}

private actor BootstrapAPIClient: APIClient {
  private let currentUserResult: Result<AuthUser, AppError>
  private let guestResult: Result<AuthSession, AppError>
  private(set) var requestPaths: [String] = []

  init(
    currentUserResult: Result<AuthUser, AppError> = .failure(.parsing),
    guestResult: Result<AuthSession, AppError> = .failure(.parsing)
  ) {
    self.currentUserResult = currentUserResult
    self.guestResult = guestResult
  }

  func send<Response: Sendable>(_ request: APIRequest<Response>) async throws -> Response {
    requestPaths.append(request.path)
    switch request.path {
    case "/me":
      guard let response = try currentUserResult.get() as? Response else {
        throw AppError.parsing
      }
      return response
    case "/auth/guest":
      guard let response = try guestResult.get() as? Response else {
        throw AppError.parsing
      }
      return response
    default:
      throw AppError.invalidRequest
    }
  }
}
