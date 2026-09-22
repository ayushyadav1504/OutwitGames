import Foundation

nonisolated struct ChallengeNearMissViewData: Equatable, Sendable {
  enum Metric: Equatable, Sendable {
    case score(Int)
    case time(milliseconds: Int)
  }

  enum Goal: Equatable, Sendable {
    case score(Int)
    case finish(milliseconds: Int)
    case moves(Int)
    case survive(milliseconds: Int)
    case collect(count: Int, metric: String)
  }

  let metric: Metric
  let goal: Goal
  let rewardCoins: Int

  static func make(
    launch: ChallengeLaunch,
    outcome: ChallengeOutcome
  ) -> ChallengeNearMissViewData {
    let objective = primaryObjective(in: launch.objective)
    let type = objective["type"]?.stringValue ?? ""
    let target = max(0, objective["target"]?.intValue ?? objective["max"]?.intValue ?? 0)

    if type == "time_limit" {
      let limit = max(0, objective["max_ms"]?.intValue ?? 0)
      return ChallengeNearMissViewData(
        metric: .time(milliseconds: max(0, outcome.runtimeMilliseconds ?? limit)),
        goal: .finish(milliseconds: limit),
        rewardCoins: max(0, launch.rewardCoins)
      )
    }

    let metricKey = objective["metric"]?.stringValue
    let score = max(0, metricKey.flatMap { outcome.metrics[$0] } ?? outcome.score ?? 0)
    let goal: Goal
    switch type {
    case "move_limit":
      goal = .moves(target)
    case "survive_duration":
      goal = .survive(milliseconds: max(0, objective["min_ms"]?.intValue ?? 0))
    case "collect_count":
      goal = .collect(count: target, metric: metricKey ?? "")
    default:
      goal = .score(target)
    }

    return ChallengeNearMissViewData(
      metric: .score(score),
      goal: goal,
      rewardCoins: max(0, launch.rewardCoins)
    )
  }

  private static func primaryObjective(
    in objective: [String: JSONValue]
  ) -> [String: JSONValue] {
    guard objective["type"]?.stringValue == "composite" else { return objective }
    return objective["terms"]?.arrayValue?
      .compactMap(\.objectValue)
      .first { $0["type"]?.stringValue != "time_limit" }
      ?? objective
  }
}
