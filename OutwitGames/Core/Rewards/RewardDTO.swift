import Foundation

nonisolated struct RewardCatalogDTO: Decodable, Sendable {
  let rewards: [RewardItemDTO]
  let cashOut: CashOutDTO?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    rewards = try container.decodeIfPresent([RewardItemDTO].self, forKey: .rewards) ?? []
    cashOut = try container.decodeIfPresent(CashOutDTO.self, forKey: .cashOut)
  }

  func domainModel() -> RewardCatalog {
    RewardCatalog(
      rewards: rewards.map(\.domainModel).filter { !$0.sku.isEmpty },
      cashOut: cashOut?.domainModel ?? CashOutEligibility(
        eligible: false,
        rewardsEnabled: false,
        unlocked: false,
        referrals: ReferralProgress(qualified: 0, needed: 0, threshold: 0)
      )
    )
  }

  enum CodingKeys: String, CodingKey {
    case rewards
    case cashOut = "cash_out"
  }
}

nonisolated struct RewardItemDTO: Decodable, Sendable {
  let sku: String
  let name: String
  let description: String
  let category: String
  let coinCost: Int
  let fiatValueCents: Int
  let currency: String
  let inventory: Int?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    sku = try container.decodeIfPresent(String.self, forKey: .sku) ?? ""
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
    coinCost = max(try container.decodeIfPresent(Int.self, forKey: .coinCost) ?? 0, 0)
    fiatValueCents = max(
      try container.decodeIfPresent(Int.self, forKey: .fiatValueCents) ?? 0,
      0
    )
    currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? ""
    inventory = try container.decodeIfPresent(Int.self, forKey: .inventory).map { max($0, 0) }
  }

  var domainModel: RewardItem {
    RewardItem(
      sku: sku,
      name: name,
      description: description,
      category: category,
      coinCost: coinCost,
      fiatValueCents: fiatValueCents,
      currency: currency,
      inventory: inventory
    )
  }

  enum CodingKeys: String, CodingKey {
    case sku, name, description, category, currency, inventory
    case coinCost = "coin_cost"
    case fiatValueCents = "fiat_value_cents"
  }
}

nonisolated struct CashOutDTO: Decodable, Sendable {
  let eligible: Bool
  let rewardsEnabled: Bool
  let unlocked: Bool
  let referrals: ReferralProgressDTO?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    eligible = try container.decodeIfPresent(Bool.self, forKey: .eligible) ?? false
    rewardsEnabled = try container.decodeIfPresent(Bool.self, forKey: .rewardsEnabled) ?? false
    unlocked = try container.decodeIfPresent(Bool.self, forKey: .unlocked) ?? false
    referrals = try container.decodeIfPresent(ReferralProgressDTO.self, forKey: .referrals)
  }

  var domainModel: CashOutEligibility {
    CashOutEligibility(
      eligible: eligible,
      rewardsEnabled: rewardsEnabled,
      unlocked: unlocked,
      referrals: referrals?.domainModel ?? ReferralProgress(qualified: 0, needed: 0, threshold: 0)
    )
  }

  enum CodingKeys: String, CodingKey {
    case eligible, unlocked, referrals
    case rewardsEnabled = "rewards_enabled"
  }
}

nonisolated struct ReferralProgressDTO: Decodable, Sendable {
  let qualified: Int
  let needed: Int
  let threshold: Int

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    qualified = try container.decodeIfPresent(Int.self, forKey: .qualified) ?? 0
    needed = try container.decodeIfPresent(Int.self, forKey: .needed) ?? 0
    threshold = try container.decodeIfPresent(Int.self, forKey: .threshold) ?? 0
  }

  var domainModel: ReferralProgress {
    ReferralProgress(
      qualified: max(qualified, 0),
      needed: max(needed, 0),
      threshold: max(threshold, 0)
    )
  }

  enum CodingKeys: String, CodingKey {
    case qualified, needed, threshold
  }
}

nonisolated struct ReferralInfoDTO: Decodable, Sendable {
  let code: String
  let shareURL: String
  let qualified: Int
  let needed: Int
  let threshold: Int
  let unlocked: Bool

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
    shareURL = try container.decodeIfPresent(String.self, forKey: .shareURL) ?? ""
    qualified = max(try container.decodeIfPresent(Int.self, forKey: .qualified) ?? 0, 0)
    needed = max(try container.decodeIfPresent(Int.self, forKey: .needed) ?? 0, 0)
    threshold = max(try container.decodeIfPresent(Int.self, forKey: .threshold) ?? 0, 0)
    unlocked = try container.decodeIfPresent(Bool.self, forKey: .unlocked) ?? false
  }

  var domainModel: ReferralInfo {
    ReferralInfo(
      code: code,
      shareURL: URL(string: shareURL),
      progress: ReferralProgress(qualified: qualified, needed: needed, threshold: threshold),
      unlocked: unlocked
    )
  }

  enum CodingKeys: String, CodingKey {
    case code, qualified, needed, threshold, unlocked
    case shareURL = "share_url"
  }
}

nonisolated struct RewardRedemptionDTO: Decodable, Sendable {
  let id: Int
  let status: String
  let coinCost: Int
  let fiatValueCents: Int
  let currency: String
  let code: String?
  let requestedAt: String?
  let settledAt: String?
  let rewardItem: RewardSummaryDTO?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
    status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
    coinCost = max(try container.decodeIfPresent(Int.self, forKey: .coinCost) ?? 0, 0)
    fiatValueCents = max(
      try container.decodeIfPresent(Int.self, forKey: .fiatValueCents) ?? 0,
      0
    )
    currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? ""
    code = try container.decodeIfPresent(String.self, forKey: .code)
    requestedAt = try container.decodeIfPresent(String.self, forKey: .requestedAt)
    settledAt = try container.decodeIfPresent(String.self, forKey: .settledAt)
    rewardItem = try container.decodeIfPresent(RewardSummaryDTO.self, forKey: .rewardItem)
  }

  func domainModel() -> RewardRedemption {
    RewardRedemption(
      id: id,
      status: RewardRedemptionStatus(wireValue: status),
      coinCost: coinCost,
      fiatValueCents: fiatValueCents,
      currency: currency,
      code: code,
      requestedAt: Self.date(from: requestedAt),
      settledAt: Self.date(from: settledAt),
      rewardSKU: rewardItem?.sku,
      rewardName: rewardItem?.name
    )
  }

  private static func date(from value: String?) -> Date? {
    guard let value else { return nil }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }

  enum CodingKeys: String, CodingKey {
    case id, status, currency, code
    case coinCost = "coin_cost"
    case fiatValueCents = "fiat_value_cents"
    case requestedAt = "requested_at"
    case settledAt = "settled_at"
    case rewardItem = "reward_item"
  }
}

nonisolated struct RewardSummaryDTO: Decodable, Sendable {
  let sku: String?
  let name: String?
}

nonisolated struct RewardRedemptionsDTO: Decodable, Sendable {
  let redemptions: [RewardRedemptionDTO]

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    redemptions = try container.decodeIfPresent([RewardRedemptionDTO].self, forKey: .redemptions) ?? []
  }

  enum CodingKeys: String, CodingKey {
    case redemptions
  }
}

nonisolated struct RewardRedemptionResponseDTO: Decodable, Sendable {
  let redemption: RewardRedemptionDTO
}
