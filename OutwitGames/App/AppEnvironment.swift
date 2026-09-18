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
  let notificationPermissionRequester: any NotificationPermissionRequesting

  init(
    settings: AppSettings = AppSettings(),
    coordinator: AppCoordinator? = nil,
    configuration: AppConfiguration = .current,
    tokenStore: (any TokenStore)? = nil,
    apiClient: (any APIClient)? = nil,
    sessionBootstrapper: (any SessionBootstrapping)? = nil,
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
        device: DeviceSnapshot.current()
      )
    self.notificationPermissionRequester =
      notificationPermissionRequester ?? NotificationPermissionRequester()
  }
}
