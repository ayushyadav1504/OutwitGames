import Foundation
import Testing

@testable import OutwitGames

struct AppConfigurationTests {
  @Test
  func bundledEnvironmentsUseTheExistingServiceEndpoints() {
    #expect(
      AppConfiguration.development.apiBaseURL.absoluteString == "https://staging.outwit.club/api")
    #expect(
      AppConfiguration.development.socketURL.absoluteString == "wss://staging.outwit.club/socket")
    #expect(AppConfiguration.production.apiBaseURL.absoluteString == "https://outwit.club/api")
    #expect(AppConfiguration.production.socketURL.absoluteString == "wss://outwit.club/socket")
  }

  @Test
  func gameNavigationAllowsOnlyConfiguredSecureHosts() throws {
    let configuration = AppConfiguration.production
    let allowed = try #require(
      URL(string: "https://outwit-games.blr1.cdn.digitaloceanspaces.com/game/index.html")
    )
    let wrongHost = try #require(URL(string: "https://example.com/game/index.html"))
    let insecure = try #require(
      URL(string: "http://outwit-games.blr1.cdn.digitaloceanspaces.com/game/index.html")
    )

    #expect(configuration.allowsGameURL(allowed))
    #expect(!configuration.allowsGameURL(wrongHost))
    #expect(!configuration.allowsGameURL(insecure))
  }

  @Test
  func insecureEndpointsRequireAnExplicitDebugOverride() {
    #expect(throws: AppConfigurationError.invalidEndpoint(name: "OUTWIT_API_BASE_URL")) {
      try AppConfiguration(
        environment: .development,
        apiBaseURL: "http://localhost:4000/api",
        socketURL: "ws://localhost:4000/socket",
        gameHosts: ["localhost"],
        postHogProjectToken: "test-token",
        postHogHostURL: "http://localhost:8000"
      )
    }
  }
}
