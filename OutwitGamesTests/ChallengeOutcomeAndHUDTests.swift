import Foundation
import Testing

@testable import OutwitGames

struct ChallengeOutcomeAndHUDTests {
  @Test
  func outcomeIsFailClosedAndOnlyAwardsFallbackRewardForExplicitWin() throws {
    let unknown = try ChallengeOutcomeMapper.map(
      ["score": .number(11)],
      fallbackRewardCoins: 5,
      fallbackTarget: 12
    )
    let won = try ChallengeOutcomeMapper.map(
      [
        "score": .number(12),
        "won": .bool(true),
        "milestones": .array([.object(["reward_coins": .number(3)])]),
      ],
      fallbackRewardCoins: 5,
      fallbackTarget: 12
    )

    #expect(!unknown.won)
    #expect(unknown.coinsEarned == 0)
    #expect(won.won)
    #expect(won.coinsEarned == 5)
    #expect(won.milestoneCoins == 3)
    #expect(won.totalCoins == 8)
  }

  @Test
  func hudUsesMetricSnapshotsAndClampsProgress() {
    let launch = launch(
      objective: [
        "type": .string("collect_count"),
        "metric": .string("stars"),
        "target": .number(10),
      ]
    )
    let initial = ChallengeHUDState.initial(launch: launch)
    let updated = initial.applying(
      .state(values: ["metrics": .object(["stars": .number(14)])], requestID: "native-0")
    )

    #expect(updated.valueText == "14")
    #expect(updated.targetText == "10")
    #expect(updated.progress == 1)
  }

  @Test
  func timerHudSettlesIncomingFramesToDisplayedMilliseconds() {
    let initial = ChallengeHUDState.initial(
      launch: launch(objective: ["type": .string("time_limit"), "max_ms": .number(80_000)])
    )
    let updated = initial.applying(.time(seconds: 19.987))

    #expect(updated.valueText == "0:19")
    #expect(updated.targetText == "1:20")
  }

  private func launch(objective: [String: JSONValue]) -> ChallengeLaunch {
    ChallengeLaunch(
      challenge: FeedChallenge(
        id: 1,
        gameKey: "test",
        title: "Test",
        objective: ChallengeObjective(raw: objective),
        difficulty: 1,
        rewardCoins: 5,
        bundle: nil,
        media: []
      ),
      gameID: "game-1",
      socketToken: "socket-token",
      socketURL: URL(string: "wss://api.example.com/socket")!,
      entryURL: URL(string: "https://games.example.com/index.html")!,
      objective: objective,
      level: nil,
      rewardCoins: 5
    )
  }
}
