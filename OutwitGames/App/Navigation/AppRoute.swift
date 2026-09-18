enum AppRoute: String, Codable, Hashable, Sendable {
  case language
  case onboarding
  case login
  case feed
  case rewards

  var accessibilityName: String {
    switch self {
    case .language: "Language"
    case .onboarding: "Onboarding"
    case .login: "Login"
    case .feed: "Feed"
    case .rewards: "Rewards"
    }
  }
}
