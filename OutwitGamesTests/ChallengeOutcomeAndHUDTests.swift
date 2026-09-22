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

  @Test
  func scoreHudMovesThroughNearTargetAndSuccessPhases() {
    let initial = ChallengeHUDState.initial(
      launch: launch(objective: ["type": .string("min_score"), "target": .number(10)])
    )

    let nearTarget = initial.applying(.score(9))
    let success = nearTarget.applying(.score(10))

    #expect(nearTarget.phase == .nearTarget)
    #expect(success.phase == .success)
  }

  @Test
  func compositeHudTracksPrimaryMetricAndTimeWarning() {
    let initial = ChallengeHUDState.initial(
      launch: launch(objective: [
        "type": .string("composite"),
        "terms": .array([
          .object([
            "type": .string("collect_count"),
            "metric": .string("stars"),
            "target": .number(10),
          ]),
          .object(["type": .string("time_limit"), "max_ms": .number(30_000)]),
        ]),
      ])
    )
    let updated = initial.applying(
      .state(
        values: [
          "metrics": .object(["stars": .number(7)]),
          "time": .number(21),
        ],
        requestID: "native-1"
      )
    )

    #expect(updated.mode == .composite)
    #expect(updated.valueText == "7")
    #expect(updated.timeText == "0:21")
    #expect(updated.timeLimitText == "0:30")
    #expect(updated.phase == .warning)
  }

  @Test
  func nearMissPresentationUsesThePrimaryCompositeGoal() {
    let challengeLaunch = launch(objective: [
      "type": .string("composite"),
      "terms": .array([
        .object([
          "type": .string("collect_count"),
          "metric": .string("stars"),
          "target": .number(10),
        ]),
        .object(["type": .string("time_limit"), "max_ms": .number(30_000)]),
      ]),
    ])
    let outcome = ChallengeOutcome(
      won: false,
      score: nil,
      target: nil,
      runtimeMilliseconds: 22_000,
      metrics: ["stars": 8],
      coinsEarned: 0,
      milestoneCoins: 0
    )

    let presentation = ChallengeNearMissViewData.make(
      launch: challengeLaunch,
      outcome: outcome
    )

    #expect(presentation.metric == .score(8))
    #expect(presentation.goal == .collect(count: 10, metric: "stars"))
    #expect(presentation.rewardCoins == 5)
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
