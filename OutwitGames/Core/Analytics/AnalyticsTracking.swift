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
