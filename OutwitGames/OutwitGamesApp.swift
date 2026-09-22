//
//  OutwitGamesApp.swift
//  OutwitGames
//
//  Created by Ayush yadav on 18/09/26.
//

import SwiftUI

@main
struct OutwitGamesApp: App {
  @UIApplicationDelegateAdaptor(OutwitAppDelegate.self) private var appDelegate
  @State private var environment: AppEnvironment

  init() {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-feed") {
        let tokenStore = UITestTokenStore()
        _environment = State(
          initialValue: AppEnvironment(
            coordinator: AppCoordinator(root: .feed),
            tokenStore: tokenStore,
            sessionBootstrapper: UITestSessionBootstrapper(),
            feedRepository: UITestFeedRepository(),
            homeRepository: UITestHomeRepository(),
            socketSession: UnavailableSocketSession(),
            challengeRepository: UITestChallengeRepository(),
            adConsentService: PermissiveAdConsentService(),
            rewardedAdService: UnavailableRewardedAdService(),
            interstitialAdService: UnavailableInterstitialAdService(),
            analytics: NoOpAnalyticsTracker()
          )
        )
        return
      }

      if ProcessInfo.processInfo.arguments.contains("-ui-testing-login") {
        let tokenStore = UITestTokenStore()
        _environment = State(
          initialValue: AppEnvironment(
            coordinator: AppCoordinator(root: .login),
            tokenStore: tokenStore,
            sessionBootstrapper: UITestSessionBootstrapper(),
            authRepository: UITestAuthRepository(),
            feedRepository: UITestFeedRepository(),
            homeRepository: UITestHomeRepository(),
            socketSession: UnavailableSocketSession(),
            adConsentService: PermissiveAdConsentService(),
            rewardedAdService: UnavailableRewardedAdService(),
            interstitialAdService: UnavailableInterstitialAdService(),
            analytics: NoOpAnalyticsTracker()
          )
        )
        return
      }

      if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
        _environment = State(
          initialValue: AppEnvironment(
            sessionBootstrapper: UITestSessionBootstrapper(),
            socketSession: UnavailableSocketSession(),
            adConsentService: PermissiveAdConsentService(),
            rewardedAdService: UnavailableRewardedAdService(),
            interstitialAdService: UnavailableInterstitialAdService(),
            analytics: NoOpAnalyticsTracker()
          )
        )
        return
      }
    #endif

    _environment = State(initialValue: AppEnvironment())
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(environment)
        .environment(\.locale, environment.settings.locale)
    }
  }
}

#if DEBUG
  private nonisolated struct UITestSessionBootstrapper: SessionBootstrapping {
    func establishSession() async throws -> Bool { true }
  }

  private nonisolated struct UITestAuthRepository: AuthRepository {
    func sendOTP(to nationalPhoneNumber: String) async throws {}

    func verifyOTP(phone: String, code: String) async throws -> AuthUser {
      AuthUser(
        id: 91,
        kind: "registered",
        username: "ui-test-player",
        phone: "+91\(phone)",
        externalID: "ui-test-91"
      )
    }

    func loginToExistingAccount(phone: String, code: String) async throws -> AuthUser {
      try await verifyOTP(phone: phone, code: code)
    }
  }

  private actor UITestTokenStore: TokenStore {
    private var session = AuthSession(
      user: AuthUser(
        id: 91,
        kind: "registered",
        username: "Swift Player",
        phone: "+919876543210",
        externalID: "ui-test-91"
      ),
      apiToken: "ui-api-token",
      socketToken: "ui-socket-token",
      refreshToken: "ui-refresh-token"
    )

    func loadSession() -> AuthSession? { session }
    func saveSession(_ session: AuthSession) { self.session = session }
    func saveUser(_ user: AuthUser) { session.user = user }
    func clear() {}
  }

  private nonisolated struct UITestFeedRepository: FeedRepository {
    func load(count: Int, forceRefresh: Bool, cursor: String?) async throws -> FeedPage {
      FeedPage(
        challenges: [
          previewChallenge(id: 101, title: "Quick Maths", target: 12),
          previewChallenge(id: 102, title: "Memory Match", target: 8),
        ],
        milestone: nil,
        nextCursor: nil
      )
    }

    private func previewChallenge(id: Int, title: String, target: Int) -> FeedChallenge {
      FeedChallenge(
        id: id,
        gameKey: "ui-test-\(id)",
        title: title,
        objective: ChallengeObjective(
          raw: ["type": .string("min_score"), "target": .number(Double(target))]
        ),
        difficulty: 1,
        rewardCoins: 5,
        bundle: FeedGameBundle(
          version: "1",
          url: "https://games.example.com/ui-test/",
          entry: "index.html"
        ),
        media: []
      )
    }
  }

  private nonisolated struct UITestHomeRepository: HomeRepository {
    func loadWallet(forceRefresh: Bool) async throws -> WalletBalance {
      WalletBalance(coins: 240, elixir: 0)
    }
  }

  private nonisolated struct UITestChallengeRepository: ChallengeRepository {
    func start(_ challenge: FeedChallenge) async throws -> ChallengeLaunch {
      ChallengeLaunch(
        challenge: challenge,
        gameID: "ui-game-\(challenge.id)",
        socketToken: "ui-socket-token",
        socketURL: URL(string: "wss://api.example.com/socket")!,
        entryURL: URL(string: "https://games.example.com/ui-test/index.html")!,
        objective: challenge.objective.raw,
        level: nil,
        rewardCoins: challenge.rewardCoins
      )
    }

    func waitForEnd(of launch: ChallengeLaunch) async throws -> ChallengeOutcome {
      try await Task.sleep(for: .seconds(30))
      throw CancellationError()
    }

    func createAdSession(
      for launch: ChallengeLaunch,
      action: ChallengeAdAction
    ) async throws -> ChallengeAdSession {
      throw AppError.server()
    }

    func amplifyWin(_ launch: ChallengeLaunch, nonce: String) async throws -> ChallengeSpin {
      throw AppError.server()
    }

    func retry(_ launch: ChallengeLaunch, nonce: String) async throws -> ChallengeLaunch {
      throw AppError.server()
    }
  }
#endif
