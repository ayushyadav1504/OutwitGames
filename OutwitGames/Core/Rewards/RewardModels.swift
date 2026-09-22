import Foundation

nonisolated enum RewardsEntrySource: String, Codable, Hashable, Sendable {
  case home = "Home"
  case game = "Game"
  case win = "Win"
  case profile = "Profile"
}

nonisolated enum RewardsTab: String, CaseIterable, Sendable {
  case available = "Available"
  case redeemed = "Redeemed"
}

nonisolated enum GiftCardSource: String, Sendable {
  case redemptionSuccess = "Redemption success"
  case redeemedHistory = "Redeemed history"
}

nonisolated struct RewardCatalog: Equatable, Sendable {
  let rewards: [RewardItem]
  let cashOut: CashOutEligibility
}

nonisolated struct CashOutEligibility: Equatable, Sendable {
  let eligible: Bool
  let rewardsEnabled: Bool
  let unlocked: Bool
  let referrals: ReferralProgress
}

nonisolated struct ReferralProgress: Equatable, Sendable {
  let qualified: Int
  let needed: Int
  let threshold: Int
}

nonisolated struct RewardItem: Equatable, Identifiable, Sendable {
  var id: String { sku }

  let sku: String
  let name: String
  let description: String
  let category: String
  let coinCost: Int
  let fiatValueCents: Int
  let currency: String
  let inventory: Int?

  var isInStock: Bool { inventory == nil || inventory! > 0 }

  func coinsNeeded(balance: Int) -> Int {
    max(coinCost - balance, 0)
  }
}

nonisolated struct ReferralInfo: Equatable, Sendable {
  let code: String
  let shareURL: URL?
  let progress: ReferralProgress
  let unlocked: Bool

  var canShare: Bool { !code.isEmpty && shareURL != nil }
}

nonisolated enum RewardRedemptionStatus: String, Equatable, Sendable {
  case pending
  case approved
  case fulfilled
  case rejected
  case refunded
  case unknown

  init(wireValue: String) {
    self = Self(rawValue: wireValue) ?? .unknown
  }

  var isAwaitingFulfillment: Bool { self == .pending || self == .approved }
  var returnsCoins: Bool { self == .rejected || self == .refunded }
}

nonisolated struct RewardRedemption: Equatable, Identifiable, Sendable {
  let id: Int
  let status: RewardRedemptionStatus
  let coinCost: Int
  let fiatValueCents: Int
  let currency: String
  let code: String?
  let requestedAt: Date?
  let settledAt: Date?
  let rewardSKU: String?
  let rewardName: String?

  var hasOutcome: Bool {
    status.isAwaitingFulfillment || (status == .fulfilled && code?.isEmpty == false)
  }

  func attaching(reward: RewardItem) -> RewardRedemption {
    RewardRedemption(
      id: id,
      status: status,
      coinCost: coinCost,
      fiatValueCents: fiatValueCents,
      currency: currency,
      code: code,
      requestedAt: requestedAt,
      settledAt: settledAt,
      rewardSKU: rewardSKU ?? reward.sku,
      rewardName: rewardName ?? reward.name
    )
  }
}
