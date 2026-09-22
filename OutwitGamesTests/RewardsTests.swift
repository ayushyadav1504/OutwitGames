import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct RewardsTests {
  @Test
  func catalogRequestMapsBackendValuesAndDefaultsOmittedProgress() throws {
    let request = RewardsCatalogRequest.make(geo: "IN")
    let catalog = try request.decodeResponse(
      from: Data(
        #"{"rewards":[{"sku":"gift-500","name":"Gift Card ₹5","coin_cost":500,"fiat_value_cents":500,"currency":"INR"}],"cash_out":{"eligible":true,"rewards_enabled":true,"unlocked":true,"referrals":{"qualified":1}}}"#
          .utf8
      )
    )

    #expect(request.path == "/rewards")
    #expect(request.queryItems == [APIQueryItem(name: "geo", value: "IN")])
    #expect(catalog.rewards.first?.sku == "gift-500")
    #expect(catalog.rewards.first?.coinCost == 500)
    #expect(catalog.cashOut.referrals == ReferralProgress(qualified: 1, needed: 0, threshold: 0))
  }

  @Test
  func pendingRedemptionPublishesFulfilledCodeAndRefreshesServerBalance() async {
    let reward = Self.reward
    let rewards = RewardsRepositorySpy(
      catalog: Self.catalog(reward: reward),
      redemption: Self.pendingRedemption,
      fulfilledRedemption: Self.fulfilledRedemption
    )
    let home = RewardsHomeRepository(wallets: [
      WalletBalance(coins: 1_000, elixir: 0),
      WalletBalance(coins: 500, elixir: 0),
    ])
    let viewModel = RewardsViewModel(
      rewardsRepository: rewards,
      referralsRepository: RewardsReferralsRepository(),
      homeRepository: home,
      tokenStore: InMemoryTokenStore(session: TestSessions.original),
      analytics: NoOpAnalyticsTracker(),
      coordinator: AppCoordinator(root: .feed),
      entrySource: .home,
      historyPollInterval: .milliseconds(1)
    )

    await viewModel.load()
    viewModel.requestRedemption(reward)
    #expect(viewModel.confirmationReward == reward)

    viewModel.confirmRedemption()
    for _ in 0..<200 where viewModel.openedRedemption?.redemption.code == nil {
      try? await Task.sleep(for: .milliseconds(1))
    }

    #expect(await rewards.redeemedSKUs == ["gift-500"])
    #expect(viewModel.openedRedemption?.redemption.code == "SAFE-CODE")
    #expect(viewModel.walletCoins == 500)
    #expect(!viewModel.isRedeeming)
  }

  private static let reward = RewardItem(
    sku: "gift-500",
    name: "Gift Card ₹5",
    description: "",
    category: "gift_card",
    coinCost: 500,
    fiatValueCents: 500,
    currency: "INR",
    inventory: 4
  )

  private static let fulfilledRedemption = RewardRedemption(
    id: 7,
    status: .fulfilled,
    coinCost: 500,
    fiatValueCents: 500,
    currency: "INR",
    code: "SAFE-CODE",
    requestedAt: nil,
    settledAt: nil,
    rewardSKU: "gift-500",
    rewardName: "Gift Card ₹5"
  )

  private static let pendingRedemption = RewardRedemption(
    id: 7,
    status: .pending,
    coinCost: 500,
    fiatValueCents: 500,
    currency: "INR",
    code: nil,
    requestedAt: nil,
    settledAt: nil,
    rewardSKU: "gift-500",
    rewardName: "Gift Card ₹5"
  )

  private static func catalog(reward: RewardItem) -> RewardCatalog {
    RewardCatalog(
      rewards: [reward],
      cashOut: CashOutEligibility(
        eligible: true,
        rewardsEnabled: true,
        unlocked: true,
        referrals: ReferralProgress(qualified: 1, needed: 0, threshold: 1)
      )
    )
  }
}

private actor RewardsRepositorySpy: RewardsRepository {
  let catalog: RewardCatalog
  let redemption: RewardRedemption
  let fulfilledRedemption: RewardRedemption
  private(set) var redeemedSKUs: [String] = []
  private var historyLoads = 0

  init(
    catalog: RewardCatalog,
    redemption: RewardRedemption,
    fulfilledRedemption: RewardRedemption
  ) {
    self.catalog = catalog
    self.redemption = redemption
    self.fulfilledRedemption = fulfilledRedemption
  }

  func loadCatalog(geo: String?) -> RewardCatalog { catalog }

  func loadRedemptions() -> [RewardRedemption] {
    defer { historyLoads += 1 }
    switch historyLoads {
    case 0: return []
    case 1: return [redemption]
    default: return [fulfilledRedemption]
    }
  }

  func redeem(sku: String, geo: String?) -> RewardRedemption {
    redeemedSKUs.append(sku)
    return redemption
  }
}

private nonisolated struct RewardsReferralsRepository: ReferralsRepository {
  func load() -> ReferralInfo {
    ReferralInfo(
      code: "OUTWIT",
      shareURL: URL(string: "https://example.com/refer/OUTWIT"),
      progress: ReferralProgress(qualified: 1, needed: 0, threshold: 1),
      unlocked: true
    )
  }
}

private actor RewardsHomeRepository: HomeRepository {
  private var wallets: [WalletBalance]

  init(wallets: [WalletBalance]) {
    self.wallets = wallets
  }

  func loadWallet(forceRefresh: Bool) throws -> WalletBalance {
    guard wallets.count > 1 else {
      guard let wallet = wallets.first else { throw AppError.parsing }
      return wallet
    }
    return wallets.removeFirst()
  }
}
