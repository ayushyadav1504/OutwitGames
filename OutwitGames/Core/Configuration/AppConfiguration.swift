import Foundation

nonisolated struct AppConfiguration: Equatable, Sendable {
  nonisolated enum Environment: String, Sendable {
    case development
    case production
  }

  let environment: Environment
  let apiBaseURL: URL
  let socketURL: URL
  let gameHosts: Set<String>
  let postHogProjectToken: String
  let postHogHostURL: URL
  let allowsInsecureTransport: Bool

  var webOrigin: URL {
    var components = URLComponents()
    components.scheme = apiBaseURL.scheme
    components.host = apiBaseURL.host
    components.port = apiBaseURL.port
    return components.url ?? apiBaseURL
  }

  var privacyPolicyURL: URL {
    webOrigin.appending(path: "privacy-policy")
  }

  var termsAndConditionsURL: URL {
    webOrigin.appending(path: "terms-and-conditions")
  }

  init(
    environment: Environment,
    apiBaseURL: String,
    socketURL: String,
    gameHosts: [String],
    postHogProjectToken: String,
    postHogHostURL: String,
    allowsInsecureTransport: Bool = false
  ) throws {
    self.environment = environment
    self.allowsInsecureTransport = allowsInsecureTransport
    self.apiBaseURL = try Self.endpoint(
      named: "OUTWIT_API_BASE_URL",
      value: apiBaseURL,
      secureScheme: "https",
      debugScheme: "http",
      allowsInsecureTransport: allowsInsecureTransport
    )
    self.socketURL = try Self.endpoint(
      named: "OUTWIT_SOCKET_URL",
      value: socketURL,
      secureScheme: "wss",
      debugScheme: "ws",
      allowsInsecureTransport: allowsInsecureTransport
    )
    self.postHogHostURL = try Self.endpoint(
      named: "POSTHOG_HOST",
      value: postHogHostURL,
      secureScheme: "https",
      debugScheme: "http",
      allowsInsecureTransport: allowsInsecureTransport
    )

    let normalizedHosts = Set(
      gameHosts
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
    )
    guard !normalizedHosts.isEmpty else {
      throw AppConfigurationError.missingGameHosts
    }
    self.gameHosts = normalizedHosts

    let token = postHogProjectToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      throw AppConfigurationError.missingPostHogProjectToken
    }
    self.postHogProjectToken = token
  }

  func allowsGameURL(_ url: URL) -> Bool {
    guard
      url.user == nil,
      url.password == nil,
      let scheme = url.scheme?.lowercased(),
      let host = url.host?.lowercased()
    else {
      return false
    }

    let secure = scheme == "https"
    let allowedDebugHTTP = allowsInsecureTransport && scheme == "http"
    return (secure || allowedDebugHTTP) && gameHosts.contains(host)
  }
}

nonisolated extension AppConfiguration {
  static let development = configured(
    environment: .development,
    apiBaseURL: "https://staging.outwit.club/api",
    socketURL: "wss://staging.outwit.club/socket",
    gameHosts: ["outwit-games-staging.blr1.cdn.digitaloceanspaces.com"]
  )

  static let production = configured(
    environment: .production,
    apiBaseURL: "https://outwit.club/api",
    socketURL: "wss://outwit.club/socket",
    gameHosts: ["outwit-games.blr1.cdn.digitaloceanspaces.com"]
  )

  static var current: AppConfiguration {
    #if DEBUG
      development
    #else
      production
    #endif
  }

  private static func configured(
    environment: Environment,
    apiBaseURL: String,
    socketURL: String,
    gameHosts: [String]
  ) -> AppConfiguration {
    do {
      return try AppConfiguration(
        environment: environment,
        apiBaseURL: apiBaseURL,
        socketURL: socketURL,
        gameHosts: gameHosts,
        postHogProjectToken: "phc_pMsErkWMNJbmJ4ujaRSYkxHwxAavgm2qz6jzFqV92PJS",
        postHogHostURL: "https://us.i.posthog.com"
      )
    } catch {
      preconditionFailure("Invalid bundled \(environment.rawValue) configuration: \(error)")
    }
  }

  private static func endpoint(
    named name: String,
    value: String,
    secureScheme: String,
    debugScheme: String,
    allowsInsecureTransport: Bool
  ) throws -> URL {
    guard
      let components = URLComponents(string: value),
      let scheme = components.scheme?.lowercased(),
      let host = components.host,
      !host.isEmpty,
      components.user == nil,
      components.password == nil,
      scheme == secureScheme || (allowsInsecureTransport && scheme == debugScheme),
      let url = components.url
    else {
      throw AppConfigurationError.invalidEndpoint(name: name)
    }
    return url
  }
}

nonisolated enum AppConfigurationError: Error, Equatable, Sendable {
  case invalidEndpoint(name: String)
  case missingGameHosts
  case missingPostHogProjectToken
}
