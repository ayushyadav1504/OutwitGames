import Foundation

nonisolated struct ChallengeHUDState: Equatable, Sendable {
  enum Mode: Equatable, Sendable {
    case score
    case timer
  }

  let mode: Mode
  let target: Int
  let metric: String?
  let rewardCoins: Int
  private(set) var value: Int

  static func initial(launch: ChallengeLaunch) -> ChallengeHUDState {
    let objective = launch.objective
    let primary = primaryObjective(from: objective)
    let type = primary["type"]?.stringValue
    let isTimer = type == "time_limit" || type == "survive_duration"
    let target =
      isTimer
      ? (primary["max_ms"]?.intValue ?? primary["min_ms"]?.intValue ?? 0)
      : (primary["target"]?.intValue ?? primary["max"]?.intValue ?? 0)
    return ChallengeHUDState(
      mode: isTimer ? .timer : .score,
      target: max(0, target),
      metric: primary["metric"]?.stringValue,
      rewardCoins: launch.rewardCoins,
      value: 0
    )
  }

  func applying(_ event: GameHUDEvent) -> ChallengeHUDState {
    var copy = self
    let candidate: Int?
    switch event {
    case .ready:
      candidate = nil
    case .score(let score):
      candidate = mode == .score ? score : nil
    case .time(let seconds):
      candidate = mode == .timer ? Int((seconds * 1_000).rounded(.down)) : nil
    case .state(let state, _):
      candidate = value(from: state)
    }
    if let candidate { copy.value = max(0, candidate) }
    return copy
  }

  var progress: Double {
    guard target > 0 else { return 0 }
    return min(1, Double(value) / Double(target))
  }

  var valueText: String {
    switch mode {
    case .score:
      value.formatted()
    case .timer:
      Self.clock(milliseconds: value)
    }
  }

  var targetText: String {
    switch mode {
    case .score:
      target.formatted()
    case .timer:
      Self.clock(milliseconds: target)
    }
  }

  private func value(from state: [String: JSONValue]) -> Int? {
    if mode == .timer {
      guard let seconds = state["time"]?.numberValue else { return nil }
      return Int((seconds * 1_000).rounded(.down))
    }
    if let metric,
      let metricValue = state["metrics"]?.objectValue?[metric]?.intValue
    {
      return metricValue
    }
    return state["score"]?.intValue
  }

  private static func primaryObjective(
    from objective: [String: JSONValue]
  ) -> [String: JSONValue] {
    guard objective["type"]?.stringValue == "composite" else { return objective }
    return objective["terms"]?.arrayValue?
      .compactMap(\.objectValue)
      .first { $0["type"]?.stringValue != "time_limit" }
      ?? objective
  }

  private static func clock(milliseconds: Int) -> String {
    let seconds = milliseconds / 1_000
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}

extension JSONValue {
  nonisolated fileprivate var numberValue: Double? {
    guard case .number(let value) = self, value.isFinite else { return nil }
    return value
  }
}
