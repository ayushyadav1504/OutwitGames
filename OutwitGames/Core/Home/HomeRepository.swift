nonisolated protocol HomeRepository: Sendable {
  func loadWallet(forceRefresh: Bool) async throws -> WalletBalance
}

nonisolated final class DefaultHomeRepository: HomeRepository, Sendable {
  private let apiClient: any APIClient
  private let tokenStore: any TokenStore
  private let cache = AccountScopedCache<WalletBalance>()

  init(apiClient: any APIClient, tokenStore: any TokenStore) {
    self.apiClient = apiClient
    self.tokenStore = tokenStore
  }

  func loadWallet(forceRefresh: Bool) async throws -> WalletBalance {
    let accountID = try await tokenStore.loadSession()?.user.id

    if !forceRefresh,
      let accountID,
      let cached = await cache.value(for: accountID)
    {
      return cached
    }

    let wallet = try await apiClient.send(HomeRequest.make())
    if let accountID {
      await cache.store(wallet, for: accountID)
    }
    return wallet
  }
}
