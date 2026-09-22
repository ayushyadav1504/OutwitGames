import Foundation

nonisolated struct ChallengeMultiplierViewData: Equatable, Sendable {
  let baseCoins: Int
  let bonusCoins: Int
  let segments: [ChallengeWheelSegment]
  let selectedIndex: Int

  init(outcome: ChallengeOutcome, spin: ChallengeSpin) {
    baseCoins = max(0, outcome.totalCoins)
    bonusCoins = spin.rewardCoins
    segments = spin.segments
    selectedIndex = max(
      0,
      spin.segments.firstIndex(where: { $0.key == spin.selectedSegmentKey }) ?? 0
    )
  }

  var totalCoins: Int { baseCoins + bonusCoins }

  var selectedSegment: ChallengeWheelSegment { segments[selectedIndex] }

  var isDoubled: Bool { baseCoins > 0 && totalCoins == baseCoins * 2 }

  var reactionImageName: String {
    bonusCoins > 0 ? "ChallengeNearMissHappy" : "ChallengeNearMissSad"
  }

  var landingRotationDegrees: Double {
    guard !segments.isEmpty else { return 0 }
    let sweep = 360 / Double(segments.count)
    let selectedCenter = Double(selectedIndex) * sweep + sweep / 2
    return 360 * 7 + 270 - selectedCenter
  }
}
