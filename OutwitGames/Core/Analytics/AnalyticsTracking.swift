import OSLog

nonisolated enum AnalyticsValue: Sendable {
  case bool(Bool)
  case integer(Int)
  case string(String)

  var description: String {
    switch self {
    case .bool(let value):
      value.description
    case .integer(let value):
      value.description
    case .string(let value):
      value
    }
  }
}

nonisolated struct AnalyticsEvent: Sendable {
  let name: String
  let properties: [String: AnalyticsValue]

  static func challengeFinished(
    challengeID: Int,
    attempt: Int,
    won: Bool,
    coins: Int
  ) -> AnalyticsEvent {
    AnalyticsEvent(
      name: "challenge_finished",
      properties: [
        "challenge_id": .integer(challengeID),
        "attempt": .integer(attempt),
        "won": .bool(won),
        "coins": .integer(coins),
      ]
    )
  }

  static func rewardedAd(
    _ stage: String,
    placement: RewardedAdPlacement,
    challengeID: Int,
    attempt: Int
  ) -> AnalyticsEvent {
    AnalyticsEvent(
      name: "rewarded_ad_\(stage)",
      properties: [
        "placement": .string(placement.rawValue),
        "challenge_id": .integer(challengeID),
        "attempt": .integer(attempt),
      ]
    )
  }

  static func bonusWheelSettled(
    challengeID: Int,
    attempt: Int,
    bonusCoins: Int
  ) -> AnalyticsEvent {
    AnalyticsEvent(
      name: "bonus_wheel_settled",
      properties: [
        "challenge_id": .integer(challengeID),
        "attempt": .integer(attempt),
        "bonus_coins": .integer(bonusCoins),
      ]
    )
  }

  static func feedInterstitialShown() -> AnalyticsEvent {
    AnalyticsEvent(
      name: "ad_shown",
      properties: [
        "ad_format": .string("interstitial"),
        "placement": .string("feed"),
      ]
    )
  }

  static func rewardsViewed(
    source: RewardsEntrySource,
    tab: RewardsTab,
    balance: Int
  ) -> AnalyticsEvent {
    AnalyticsEvent(
      name: "redeem_rewards_viewed",
      properties: [
        "source": .string(source.rawValue),
        "tab": .string(tab.rawValue),
        "reward_balance": .integer(balance),
      ]
    )
  }

  static func redemptionInitiated(
    reward: RewardItem,
    redemptionID: String,
    balance: Int
  ) -> AnalyticsEvent {
    AnalyticsEvent(
      name: "reward_redemption_initiated",
      properties: [
        "reward_id": .string(reward.sku),
        "reward_value": .integer(max(reward.fiatValueCents, 0) / 100),
        "currency": .string(reward.currency),
        "redemption_id": .string(redemptionID),
        "coins_required": .integer(reward.coinCost),
        "coin_balance": .integer(balance),
      ]
    )
  }

  static func rewardRedeemed(
    _ redemption: RewardRedemption,
    redemptionID: String,
    balance: Int
  ) -> AnalyticsEvent {
    AnalyticsEvent(
      name: "reward_redeemed",
      properties: [
        "reward_id": .string(redemption.rewardSKU ?? ""),
        "reward_name": .string(redemption.rewardName ?? ""),
        "redemption_id": .string(redemptionID),
        "reward_value": .integer(max(redemption.fiatValueCents, 0) / 100),
        "currency": .string(redemption.currency),
        "coins_spent": .integer(redemption.coinCost),
        "coin_balance": .integer(balance),
      ]
    )
  }

  static func redemptionFailed(
    rewardID: String,
    valueCents: Int,
    currency: String,
    redemptionID: String,
    coinsRequired: Int,
    reason: String,
    coinsRefunded: Int,
    balance: Int
  ) -> AnalyticsEvent {
    AnalyticsEvent(
      name: "reward_redemption_failed",
      properties: [
        "reward_id": .string(rewardID),
        "reward_value": .integer(max(valueCents, 0) / 100),
        "currency": .string(currency),
        "redemption_id": .string(redemptionID),
        "coins_required": .integer(coinsRequired),
        "failure_reason": .string(reason),
        "coins_refunded": .integer(coinsRefunded),
        "coin_balance": .integer(balance),
      ]
    )
  }

  static func giftCardViewed(
    _ redemption: RewardRedemption,
    redemptionID: String,
    source: GiftCardSource
  ) -> AnalyticsEvent {
    giftCardEvent(
      name: "gift_card_viewed",
      redemption: redemption,
      redemptionID: redemptionID,
      source: source
    )
  }

  static func giftCardCodeCopied(
    _ redemption: RewardRedemption,
    redemptionID: String,
    source: GiftCardSource
  ) -> AnalyticsEvent {
    giftCardEvent(
      name: "gift_card_code_copied",
      redemption: redemption,
      redemptionID: redemptionID,
      source: source
    )
  }

  private static func giftCardEvent(
    name: String,
    redemption: RewardRedemption,
    redemptionID: String,
    source: GiftCardSource
  ) -> AnalyticsEvent {
    AnalyticsEvent(
      name: name,
      properties: [
        "reward_id": .string(redemption.rewardSKU ?? ""),
        "reward_value": .integer(max(redemption.fiatValueCents, 0) / 100),
        "currency": .string(redemption.currency),
        "redemption_id": .string(redemptionID),
        "source": .string(source.rawValue),
      ]
    )
  }
}

nonisolated protocol AnalyticsTracking: Sendable {
  func track(_ event: AnalyticsEvent) async
}

nonisolated struct OSLogAnalyticsTracker: AnalyticsTracking {
  private let logger = Logger(subsystem: "club.outwit.games", category: "analytics")

  func track(_ event: AnalyticsEvent) async {
    let properties = event.properties
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value.description)" }
      .joined(separator: " ")
    logger.info("event=\(event.name, privacy: .public) \(properties, privacy: .public)")
  }
}

nonisolated struct NoOpAnalyticsTracker: AnalyticsTracking {
  func track(_ event: AnalyticsEvent) async {}
}
