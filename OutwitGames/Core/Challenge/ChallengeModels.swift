import Foundation

nonisolated struct ChallengeConfiguration: Equatable, Sendable {
  let objective: [String: JSONValue]
  let level: [String: JSONValue]?
}

nonisolated struct ChallengeLaunch: Equatable, Sendable {
  let challenge: FeedChallenge
  let gameID: String
  let socketToken: String
  let socketURL: URL
  let entryURL: URL
  let objective: [String: JSONValue]
  let level: [String: JSONValue]?
  let rewardCoins: Int

  var hostConfiguration: [String: JSONValue] {
    [
      "gameId": .string(gameID),
      "token": .string(socketToken),
      "url": .string(socketURL.absoluteString),
      "challenge": .object([
        "level": level.map(JSONValue.object) ?? .null,
        "objective": .object(objective),
      ]),
    ]
  }
}

nonisolated struct ChallengeOutcome: Equatable, Sendable {
  let won: Bool
  let score: Int?
  let target: Int?
  let runtimeMilliseconds: Int?
  let metrics: [String: Int]
  let coinsEarned: Int
  let milestoneCoins: Int

  var totalCoins: Int { coinsEarned + milestoneCoins }
}
