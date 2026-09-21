import Foundation

nonisolated protocol ChallengeRealtimeService: Sendable {
  func queryChallenge(gameID: String) async throws -> ChallengeConfiguration
  func waitForEnd(gameID: String) async throws -> [String: JSONValue]
  func createAdSession(gameID: String, action: ChallengeAdAction) async throws
    -> [String: JSONValue]
  func spin(gameID: String, nonce: String) async throws -> [String: JSONValue]
  func retry(gameID: String, nonce: String) async throws -> [String: JSONValue]
}

nonisolated final class DefaultChallengeRealtimeService: ChallengeRealtimeService, Sendable {
  private let socketSession: any SocketSession
  private let gameEndTimeout: Duration

  init(
    socketSession: any SocketSession,
    gameEndTimeout: Duration = .seconds(1_200)
  ) {
    self.socketSession = socketSession
    self.gameEndTimeout = gameEndTimeout
  }

  func queryChallenge(gameID: String) async throws -> ChallengeConfiguration {
    let topic = Self.topic(gameID)
    _ = try await socketSession.acquire(topic: topic)
    do {
      let response = try await socketSession.push(
        topic: topic,
        event: "query",
        payload: ["v": .number(1), "q": .string("challenge")]
      )
      guard let objective = response["objective"]?.objectValue else { throw AppError.parsing }
      let level: [String: JSONValue]?
      switch response["level"] {
      case .object(let value):
        level = value
      case .none, .null:
        level = nil
      default:
        throw AppError.parsing
      }
      try Task.checkCancellation()
      return ChallengeConfiguration(objective: objective, level: level)
    } catch {
      await socketSession.release(topic: topic)
      throw error
    }
  }

  func waitForEnd(gameID: String) async throws -> [String: JSONValue] {
    let topic = Self.topic(gameID)
    let events = await socketSession.events()
    let timeout = gameEndTimeout
    do {
      let payload = try await withThrowingTaskGroup(of: [String: JSONValue].self) { group in
        group.addTask {
          for await event in events where event.topic == topic && event.event == "ended" {
            return event.payload
          }
          throw AppError.server()
        }
        group.addTask {
          try await Task.sleep(for: timeout)
          throw AppError.networkTimeout
        }
        defer { group.cancelAll() }
        guard let payload = try await group.next() else { throw AppError.server() }
        return payload
      }
      await socketSession.release(topic: topic)
      return payload
    } catch {
      await socketSession.release(topic: topic)
      throw error
    }
  }

  func createAdSession(
    gameID: String,
    action: ChallengeAdAction
  ) async throws -> [String: JSONValue] {
    do {
      return try await scopedPush(
        gameID: gameID,
        event: "ad_session",
        payload: ["type": .string(action.rawValue)]
      )
    } catch let error as AppError
      where ["invalid_type", "ad_session_failed"].contains(
        error.messageKey)
    {
      throw AppError.server(messageKey: "rewarded_ad_session_failed")
    }
  }

  func spin(gameID: String, nonce: String) async throws -> [String: JSONValue] {
    do {
      return try await scopedPush(
        gameID: gameID,
        event: "spin",
        payload: ["nonce": .string(nonce)]
      )
    } catch let error as AppError {
      if error.messageKey == "not_eligible" {
        throw AppError.validation(messageKey: "multiplier_not_eligible")
      }
      if Self.invalidAdSessionReasons.contains(error.messageKey) {
        throw AppError.validation(messageKey: "rewarded_ad_session_expired")
      }
      throw error
    }
  }

  func retry(gameID: String, nonce: String) async throws -> [String: JSONValue] {
    do {
      return try await scopedPush(
        gameID: gameID,
        event: "retry",
        payload: ["nonce": .string(nonce)]
      )
    } catch let error as AppError {
      if Self.invalidAdSessionReasons.contains(error.messageKey) {
        throw AppError.validation(messageKey: "rewarded_ad_session_expired")
      }
      if error.messageKey == "already_completed" {
        throw AppError.validation(messageKey: "challenge_already_completed")
      }
      if ["not_a_challenge", "not_found", "challenge_not_found"].contains(error.messageKey) {
        throw AppError.validation(messageKey: "challenge_not_available")
      }
      throw error
    }
  }

  private func scopedPush(
    gameID: String,
    event: String,
    payload: [String: JSONValue]
  ) async throws -> [String: JSONValue] {
    let topic = Self.topic(gameID)
    _ = try await socketSession.acquire(topic: topic)
    do {
      let response = try await socketSession.push(topic: topic, event: event, payload: payload)
      await socketSession.release(topic: topic)
      return response
    } catch {
      await socketSession.release(topic: topic)
      throw error
    }
  }

  private static func topic(_ gameID: String) -> String { "match:\(gameID)" }

  private static let invalidAdSessionReasons: Set<String> = [
    "nonce_required",
    "ad_session_not_found",
    "ad_session_type_mismatch",
    "ad_session_consumed",
  ]
}
