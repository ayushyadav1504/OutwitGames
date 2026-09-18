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

  init(
    settings: AppSettings = AppSettings(),
    coordinator: AppCoordinator? = nil,
    configuration: AppConfiguration = .current,
    tokenStore: (any TokenStore)? = nil,
    apiClient: (any APIClient)? = nil
  ) {
    let resolvedCoordinator =
      coordinator
      ?? AppCoordinator(
        root: settings.language == nil ? .language : .onboarding
      )
    let resolvedTokenStore =
      tokenStore
      ?? KeychainTokenStore(
        service: "\(Bundle.main.bundleIdentifier ?? "club.outwit.games").session"
      )

    self.settings = settings
    self.coordinator = resolvedCoordinator
    self.configuration = configuration
    self.tokenStore = resolvedTokenStore
    self.apiClient =
      apiClient
      ?? URLSessionAPIClient(
        baseURL: configuration.apiBaseURL,
        tokenStore: resolvedTokenStore,
        onSessionInvalidated: { [weak resolvedCoordinator] in
          await resolvedCoordinator?.reset(to: .login)
        }
      )
  }
}
