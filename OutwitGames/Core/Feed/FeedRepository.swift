nonisolated protocol FeedRepository: Sendable {
  func load(count: Int, forceRefresh: Bool, cursor: String?) async throws -> FeedPage
}

nonisolated final class DefaultFeedRepository: FeedRepository, Sendable {
  private let apiClient: any APIClient
  private let tokenStore: any TokenStore
  private let cache = AccountScopedCache<FeedPage>()

  init(apiClient: any APIClient, tokenStore: any TokenStore) {
    self.apiClient = apiClient
    self.tokenStore = tokenStore
  }

  func load(count: Int, forceRefresh: Bool, cursor: String?) async throws -> FeedPage {
    let accountID = try await tokenStore.loadSession()?.user.id

    if cursor == nil,
      !forceRefresh,
      let accountID,
      let cached = await cache.value(for: accountID)
    {
      return cached
    }

    let page = try await apiClient.send(FeedRequest.make(count: count, cursor: cursor))
    if cursor == nil, let accountID {
      await cache.store(page, for: accountID)
    }
    return page
  }
}
