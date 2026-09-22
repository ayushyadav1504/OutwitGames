import Foundation

enum RewardsPhase: Equatable, Sendable {
  case idle
  case loading
  case loaded
  case failed(messageKey: String)
}

struct OpenedRedemption: Equatable, Sendable {
  let redemption: RewardRedemption
  let source: GiftCardSource
}
