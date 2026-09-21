import Foundation
import Observation

/// The application composition root.
///
/// Shared dependencies are created here and injected into feature composition
/// boundaries. Feature views must not resolve global services themselves.
@MainActor
@Observable
final class AppEnvironment {
  let coordinator: AppCoordinator
  let settings: AppSettings
  let configuration: AppConfiguration
  let tokenStore: any TokenStore
  let apiClient: any APIClient
  let sessionBootstrapper: any SessionBootstrapping
  let authRepository: any AuthRepository
  let feedRepository: any FeedRepository
  let homeRepository: any HomeRepository
  let socketSession: any SocketSession
  let challengeRepository: any ChallengeRepository
  let challengeOrientationController: any ChallengeOrientationControlling
  let notificationPermissionRequester: any NotificationPermissionRequesting

  init(
    settings: AppSettings = AppSettings(),
    coordinator: AppCoordinator? = nil,
    configuration: AppConfiguration = .current,
    tokenStore: (any TokenStore)? = nil,
    apiClient: (any APIClient)? = nil,
    sessionBootstrapper: (any SessionBootstrapping)? = nil,
    authRepository: (any AuthRepository)? = nil,
    feedRepository: (any FeedRepository)? = nil,
    homeRepository: (any HomeRepository)? = nil,
    socketSession: (any SocketSession)? = nil,
    challengeRepository: (any ChallengeRepository)? = nil,
    challengeOrientationController: (any ChallengeOrientationControlling)? = nil,
    notificationPermissionRequester: (any NotificationPermissionRequesting)? = nil
  ) {
    let resolvedCoordinator =
      coordinator
      ?? AppCoordinator(root: .splash)
    let resolvedTokenStore =
      tokenStore
      ?? KeychainTokenStore(
        service: "\(Bundle.main.bundleIdentifier ?? "club.outwit.games").session"
      )

    let resolvedAPIClient =
      apiClient
      ?? URLSessionAPIClient(
        baseURL: configuration.apiBaseURL,
        tokenStore: resolvedTokenStore,
        onSessionInvalidated: { [weak resolvedCoordinator] in
          await MainActor.run {
            guard let resolvedCoordinator, resolvedCoordinator.root != .splash else { return }
            resolvedCoordinator.reset(to: .login)
          }
        }
      )
    let device = DeviceSnapshot.current()
    let resolvedSocketSession =
      socketSession
      ?? AppSocketSession(
        endpoint: configuration.socketURL,
        tokenStore: resolvedTokenStore
      )

    self.settings = settings
    self.coordinator = resolvedCoordinator
    self.configuration = configuration
    self.tokenStore = resolvedTokenStore
    self.apiClient = resolvedAPIClient
    self.sessionBootstrapper =
      sessionBootstrapper
      ?? SessionBootstrapper(
        apiClient: resolvedAPIClient,
        tokenStore: resolvedTokenStore,
        device: device
      )
    self.authRepository =
      authRepository
      ?? DefaultAuthRepository(
        apiClient: resolvedAPIClient,
        tokenStore: resolvedTokenStore,
        device: device
      )
    self.feedRepository =
      feedRepository
      ?? DefaultFeedRepository(apiClient: resolvedAPIClient, tokenStore: resolvedTokenStore)
    self.homeRepository =
      homeRepository
      ?? DefaultHomeRepository(apiClient: resolvedAPIClient, tokenStore: resolvedTokenStore)
    self.socketSession = resolvedSocketSession
    self.challengeRepository =
      challengeRepository
      ?? DefaultChallengeRepository(
        apiClient: resolvedAPIClient,
        realtime: DefaultChallengeRealtimeService(socketSession: resolvedSocketSession),
        configuration: configuration
      )
    self.challengeOrientationController =
      challengeOrientationController ?? AppOrientationController.shared
    self.notificationPermissionRequester =
      notificationPermissionRequester ?? NotificationPermissionRequester()
  }
}
