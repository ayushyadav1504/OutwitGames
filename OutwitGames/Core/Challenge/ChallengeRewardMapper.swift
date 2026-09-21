import Foundation

nonisolated enum ChallengeRewardMapper {
  static func adSession(_ payload: [String: JSONValue]) throws -> ChallengeAdSession {
    guard let nonce = nonempty(payload["nonce"]?.stringValue) else { throw AppError.parsing }
    return ChallengeAdSession(nonce: nonce)
  }

  static func spin(_ payload: [String: JSONValue]) throws -> ChallengeSpin {
    guard
      let selectedKey = nonempty(payload["segment_key"]?.stringValue),
      let rewardCoins = payload["reward_coins"]?.intValue,
      rewardCoins >= 0,
      let rawSegments = payload["segments"]?.arrayValue
    else {
      throw AppError.parsing
    }

    let segments = rawSegments.compactMap { value -> ChallengeWheelSegment? in
      guard
        let raw = value.objectValue,
        let key = nonempty(raw["key"]?.stringValue)
      else {
        return nil
      }
      return ChallengeWheelSegment(
        key: key,
        label: nonempty(raw["label"]?.stringValue) ?? key,
        colorHex: raw["color"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      )
    }
    guard !segments.isEmpty, segments.contains(where: { $0.key == selectedKey }) else {
      throw AppError.parsing
    }
    return ChallengeSpin(
      selectedSegmentKey: selectedKey,
      rewardCoins: rewardCoins,
      segments: segments
    )
  }

  static func startedChallenge(_ payload: [String: JSONValue]) throws -> StartedChallenge {
    guard
      let gameID = nonempty(payload["game_id"]?.stringValue),
      let socketToken = nonempty(payload["socket_token"]?.stringValue)
    else {
      throw AppError.parsing
    }
    let challenge = payload["challenge"]?.objectValue
    return StartedChallenge(
      gameID: gameID,
      gameKey: payload["game_key"]?.stringValue ?? "",
      status: payload["status"]?.stringValue ?? "started",
      socketToken: socketToken,
      objective: challenge?["objective"]?.objectValue,
      level: challenge?["level"]?.objectValue,
      rewardCoins: challenge?["reward_coins"]?.intValue ?? 0
    )
  }

  private static func nonempty(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }
}
