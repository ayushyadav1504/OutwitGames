nonisolated protocol RewardsRepository: Sendable {
  func loadCatalog(geo: String?) async throws -> RewardCatalog
  func loadRedemptions() async throws -> [RewardRedemption]
  func redeem(sku: String, geo: String?) async throws -> RewardRedemption
}

nonisolated final class DefaultRewardsRepository: RewardsRepository, Sendable {
  private let apiClient: any APIClient

  init(apiClient: any APIClient) {
    self.apiClient = apiClient
  }

  func loadCatalog(geo: String? = nil) async throws -> RewardCatalog {
    try await apiClient.send(RewardsCatalogRequest.make(geo: geo))
  }

  func loadRedemptions() async throws -> [RewardRedemption] {
    try await apiClient.send(RewardRedemptionsRequest.make())
  }

  func redeem(sku: String, geo: String? = nil) async throws -> RewardRedemption {
    try await apiClient.send(RedeemRewardRequest.make(sku: sku, geo: geo))
  }
}

nonisolated protocol ReferralsRepository: Sendable {
  func load() async throws -> ReferralInfo
}

nonisolated final class DefaultReferralsRepository: ReferralsRepository, Sendable {
  private let apiClient: any APIClient

  init(apiClient: any APIClient) {
    self.apiClient = apiClient
  }

  func load() async throws -> ReferralInfo {
    try await apiClient.send(ReferralInfoRequest.make())
  }
}
