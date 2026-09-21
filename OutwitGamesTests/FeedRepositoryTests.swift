import Foundation
import Testing

@testable import OutwitGames

struct FeedRepositoryTests {
  @Test
  func firstPageCacheIsScopedToTheAuthenticatedAccount() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let client = QueuedJSONAPIClient(responses: ["/feed": [Self.firstPage, Self.secondPage]])
    let repository = DefaultFeedRepository(apiClient: client, tokenStore: store)

    let first = try await repository.load(count: 5, forceRefresh: true, cursor: nil)
    let cached = try await repository.load(count: 5, forceRefresh: false, cursor: nil)

    #expect(first == cached)
    #expect(await client.requestCount(for: "/feed") == 1)

    try await store.saveSession(Self.otherSession)
    let secondAccount = try await repository.load(count: 5, forceRefresh: false, cursor: nil)

    #expect(secondAccount.challenges.first?.id == 2)
    #expect(await client.requestCount(for: "/feed") == 2)
  }

  @Test
  func continuationPagesAlwaysUseTheNetworkAndDoNotReplaceFirstPageCache() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let client = QueuedJSONAPIClient(responses: ["/feed": [Self.firstPage, Self.secondPage]])
    let repository = DefaultFeedRepository(apiClient: client, tokenStore: store)

    let first = try await repository.load(count: 5, forceRefresh: true, cursor: nil)
    let continuation = try await repository.load(count: 5, forceRefresh: false, cursor: "next")
    let cached = try await repository.load(count: 5, forceRefresh: false, cursor: nil)

    #expect(first.challenges.first?.id == 1)
    #expect(continuation.challenges.first?.id == 2)
    #expect(cached.challenges.first?.id == 1)
    #expect(await client.requestCount(for: "/feed") == 2)
  }

  @Test
  func walletCacheDoesNotCrossAccountBoundaries() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let client = QueuedJSONAPIClient(responses: [
      "/home": [
        Data(#"{"wallet":{"coins":10,"elixir":0}}"#.utf8),
        Data(#"{"wallet":{"coins":99,"elixir":0}}"#.utf8),
      ]
    ])
    let repository = DefaultHomeRepository(apiClient: client, tokenStore: store)

    #expect(try await repository.loadWallet(forceRefresh: true).coins == 10)
    #expect(try await repository.loadWallet(forceRefresh: false).coins == 10)

    try await store.saveSession(Self.otherSession)
    #expect(try await repository.loadWallet(forceRefresh: false).coins == 99)
    #expect(await client.requestCount(for: "/home") == 2)
  }

  private static let firstPage = Data(
    #"{"feed":[{"challenge_id":1,"objective":{"type":"clear_all"}}],"pagination":{"has_more":true,"next_cursor":"next"}}"#
      .utf8
  )
  private static let secondPage = Data(
    #"{"feed":[{"challenge_id":2,"objective":{"type":"clear_all"}}],"pagination":{"has_more":false}}"#
      .utf8
  )
  private static let otherSession = AuthSession(
    user: AuthUser(id: 202, kind: "guest", username: "other", phone: "", externalID: ""),
    apiToken: "other-api",
    socketToken: "other-socket",
    refreshToken: "other-refresh"
  )
}

private actor QueuedJSONAPIClient: APIClient {
  private var responses: [String: [Data]]
  private var paths: [String] = []

  init(responses: [String: [Data]]) {
    self.responses = responses
  }

  func send<Response: Sendable>(_ request: APIRequest<Response>) async throws -> Response {
    paths.append(request.path)
    guard var queue = responses[request.path], !queue.isEmpty else {
      throw AppError.invalidRequest
    }
    let data = queue.removeFirst()
    responses[request.path] = queue
    return try request.decodeResponse(from: data)
  }

  func requestCount(for path: String) -> Int {
    paths.count { $0 == path }
  }
}
