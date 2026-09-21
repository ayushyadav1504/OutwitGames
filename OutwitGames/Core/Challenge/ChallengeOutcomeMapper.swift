import Foundation

nonisolated enum ChallengeOutcomeMapper {
  static func map(
    _ payload: [String: JSONValue],
    fallbackRewardCoins: Int,
    fallbackTarget: Int?
  ) throws -> ChallengeOutcome {
    let challenge = payload["challenge"]?.objectValue ?? [:]
    let metadata = payload["metadata"]?.objectValue ?? [:]
    let score = payload["score"]?.intValue ?? challenge["score"]?.intValue
    let target = payload["target"]?.intValue ?? challenge["target"]?.intValue ?? fallbackTarget
    let won = explicitWin(in: payload, challenge: challenge) ?? false
    let coins = firstInteger(
      payload["coins_earned"],
      payload["coins_awarded"],
      challenge["coins_earned"],
      challenge["reward_coins"],
      payload["coins"]
    )

    return ChallengeOutcome(
      won: won,
      score: score,
      target: target,
      runtimeMilliseconds: metadata["runtime_ms"]?.intValue,
      metrics: metadata.compactMapValues(\.intValue),
      coinsEarned: won ? (coins ?? fallbackRewardCoins) : 0,
      milestoneCoins: milestoneCoins(payload["milestones"] ?? challenge["milestones"])
    )
  }

  private static func explicitWin(
    in payload: [String: JSONValue],
    challenge: [String: JSONValue]
  ) -> Bool? {
    if case .bool(let value) = payload["won"] { return value }
    if case .bool(let value) = payload["challenge_won"] { return value }
    if case .bool(let value) = challenge["met"] { return value }
    if case .bool(let value) = challenge["won"] { return value }

    let outcome =
      challenge["objective_outcome"]?.stringValue
      ?? payload["outcome"]?.stringValue
      ?? challenge["outcome"]?.stringValue
    switch outcome {
    case "won", "win", "met", "challenge_win":
      return true
    case "lost", "loss", "missed":
      return false
    default:
      return nil
    }
  }

  private static func firstInteger(_ values: JSONValue?...) -> Int? {
    values.lazy.compactMap { $0?.intValue }.first
  }

  private static func milestoneCoins(_ value: JSONValue?) -> Int {
    value?.arrayValue?.reduce(into: 0) { result, item in
      result += item.objectValue?["reward_coins"]?.intValue ?? 0
    } ?? 0
  }
}
