import Foundation

nonisolated enum StartChallengeRequest {
  static func make(challengeID: Int) -> APIRequest<StartedChallenge> {
    APIRequest(
      path: "/feed/\(challengeID)/start",
      method: .post,
      decoding: StartedChallengeDTO.self,
      map: { try $0.domainModel() }
    )
  }
}

nonisolated struct StartedChallenge: Equatable, Sendable {
  let gameID: String
  let gameKey: String
  let status: String
  let socketToken: String
  let objective: [String: JSONValue]?
  let level: [String: JSONValue]?
  let rewardCoins: Int
}

private nonisolated struct StartedChallengeDTO: Decodable, Sendable {
  let gameID: String
  let gameKey: String
  let status: String
  let socketToken: String
  let challenge: ChallengeDTO?

  enum CodingKeys: String, CodingKey {
    case gameID = "game_id"
    case gameKey = "game_key"
    case status
    case socketToken = "socket_token"
    case challenge
  }

  func domainModel() throws -> StartedChallenge {
    guard !gameID.isEmpty, !socketToken.isEmpty else { throw AppError.parsing }
    return StartedChallenge(
      gameID: gameID,
      gameKey: gameKey,
      status: status,
      socketToken: socketToken,
      objective: challenge?.objective,
      level: challenge?.level,
      rewardCoins: challenge?.rewardCoins ?? 0
    )
  }
}

private nonisolated struct ChallengeDTO: Decodable, Sendable {
  let objective: [String: JSONValue]?
  let level: [String: JSONValue]?
  let rewardCoins: Int?

  enum CodingKeys: String, CodingKey {
    case objective
    case level
    case rewardCoins = "reward_coins"
  }
}
