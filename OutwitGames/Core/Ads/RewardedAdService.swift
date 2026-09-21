import Foundation

nonisolated enum RewardedAdPlacement: String, Sendable {
  case multiplier
  case retry
}

nonisolated enum RewardedAdOutcome: Equatable, Sendable {
  case earned
  case dismissed
  case unavailable
}

@MainActor
protocol RewardedAdServing: AnyObject {
  func initialize() async
  func load(_ placement: RewardedAdPlacement) async
  func show(
    _ placement: RewardedAdPlacement,
    userID: String,
    customData: String
  ) async -> RewardedAdOutcome
}

@MainActor
protocol AdConsentServicing: AnyObject {
  var canRequestAds: Bool { get }
  var isPrivacyOptionsRequired: Bool { get }

  func prepare() async
  func presentPrivacyOptions() async throws
}

@MainActor
final class UnavailableRewardedAdService: RewardedAdServing {
  func initialize() async {}
  func load(_ placement: RewardedAdPlacement) async {}

  func show(
    _ placement: RewardedAdPlacement,
    userID: String,
    customData: String
  ) async -> RewardedAdOutcome {
    .unavailable
  }
}

@MainActor
final class PermissiveAdConsentService: AdConsentServicing {
  let canRequestAds = true
  let isPrivacyOptionsRequired = false

  func prepare() async {}
  func presentPrivacyOptions() async throws {}
}
