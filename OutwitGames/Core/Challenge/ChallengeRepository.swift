import Foundation

nonisolated protocol ChallengeRepository: Sendable {
  func start(_ challenge: FeedChallenge) async throws -> ChallengeLaunch
  func waitForEnd(of launch: ChallengeLaunch) async throws -> ChallengeOutcome
}

nonisolated final class DefaultChallengeRepository: ChallengeRepository, Sendable {
  private let apiClient: any APIClient
  private let realtime: any ChallengeRealtimeService
  private let configuration: AppConfiguration

  init(
    apiClient: any APIClient,
    realtime: any ChallengeRealtimeService,
    configuration: AppConfiguration
  ) {
    self.apiClient = apiClient
    self.realtime = realtime
    self.configuration = configuration
  }

  func start(_ challenge: FeedChallenge) async throws -> ChallengeLaunch {
    let entryURL = try validatedEntryURL(for: challenge)
    let started = try await apiClient.send(StartChallengeRequest.make(challengeID: challenge.id))
    let sessionEntryURL = try Self.entryURL(entryURL, sessionID: started.gameID)
    let challengeConfiguration = try await realtime.queryChallenge(gameID: started.gameID)

    return ChallengeLaunch(
      challenge: challenge,
      gameID: started.gameID,
      socketToken: started.socketToken,
      socketURL: configuration.socketURL,
      entryURL: sessionEntryURL,
      objective: challengeConfiguration.objective,
      level: challengeConfiguration.level,
      rewardCoins: started.rewardCoins > 0 ? started.rewardCoins : challenge.rewardCoins
    )
  }

  func waitForEnd(of launch: ChallengeLaunch) async throws -> ChallengeOutcome {
    let payload = try await realtime.waitForEnd(gameID: launch.gameID)
    return try ChallengeOutcomeMapper.map(
      payload,
      fallbackRewardCoins: launch.rewardCoins,
      fallbackTarget: launch.objective["target"]?.intValue
    )
  }

  private func validatedEntryURL(for challenge: FeedChallenge) throws -> URL {
    guard
      let value = challenge.bundle?.entryURLString,
      let url = URL(string: value),
      configuration.allowsGameURL(url)
    else {
      throw AppError.validation(messageKey: "game_load_failed")
    }
    return url
  }

  private static func entryURL(_ entryURL: URL, sessionID: String) throws -> URL {
    guard var components = URLComponents(url: entryURL, resolvingAgainstBaseURL: false) else {
      throw AppError.validation(messageKey: "game_load_failed")
    }
    components.fragment = nil
    var items = components.queryItems?.filter { $0.name != "_outwit_session" } ?? []
    items.append(URLQueryItem(name: "_outwit_session", value: sessionID))
    components.queryItems = items
    guard let result = components.url else {
      throw AppError.validation(messageKey: "game_load_failed")
    }
    return result
  }
}
