enum AppRoute: Codable, Hashable, Sendable {
  case splash
  case language
  case onboarding
  case login
  case feed
  case rewards(RewardsEntrySource)
  case challenge(FeedChallenge)
}
