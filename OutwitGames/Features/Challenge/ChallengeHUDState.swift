import Foundation

nonisolated struct ChallengeHUDState: Equatable, Sendable {
  enum Mode: Equatable, Sendable {
    case score
    case timer
    case composite
  }

  enum Phase: Equatable, Sendable {
    case progress
    case nearTarget
    case warning
    case expired
    case failure
    case success
  }

  let mode: Mode
  let target: Int
  let metric: String?
  let rewardCoins: Int
  let timeLimitMilliseconds: Int
  private(set) var value: Int
  private(set) var timeMilliseconds: Int
  private(set) var phase: Phase

  static func initial(launch: ChallengeLaunch) -> ChallengeHUDState {
    let objective = launch.objective
    let terms = objective["terms"]?.arrayValue?.compactMap(\.objectValue) ?? []
    let isComposite = objective["type"]?.stringValue == "composite"
    let primary =
      isComposite
      ? (terms.first { $0["type"]?.stringValue != "time_limit" } ?? objective)
      : objective
    let type = primary["type"]?.stringValue
    let isTimer = type == "time_limit" || type == "survive_duration"
    let timeLimit =
      terms
      .filter { $0["type"]?.stringValue == "time_limit" }
      .compactMap { $0["max_ms"]?.intValue }
      .filter { $0 > 0 }
      .min() ?? 0
    let target =
      isTimer
      ? (primary["max_ms"]?.intValue ?? primary["min_ms"]?.intValue ?? 0)
      : (primary["target"]?.intValue ?? primary["max"]?.intValue ?? 0)

    return ChallengeHUDState(
      mode: isComposite ? .composite : (isTimer ? .timer : .score),
      target: max(0, target),
      metric: primary["metric"]?.stringValue,
      rewardCoins: launch.rewardCoins,
      timeLimitMilliseconds: timeLimit,
      value: 0,
      timeMilliseconds: 0,
      phase: .progress
    )
  }

  func applying(_ event: GameHUDEvent) -> ChallengeHUDState {
    var copy = self
    var snapshot: [String: JSONValue]?

    switch event {
    case .ready:
      return self
    case .score(let score):
      if mode != .timer { copy.value = max(0, score) }
    case .time(let seconds):
      let milliseconds = Self.milliseconds(seconds)
      if mode == .timer {
        copy.value = milliseconds
      } else if mode == .composite {
        copy.timeMilliseconds = milliseconds
      }
    case .state(let values, _):
      snapshot = values
      if mode == .timer {
        if let seconds = values["time"]?.numberValue {
          copy.value = Self.milliseconds(seconds)
        }
      } else {
        if let metric,
          let metricValue = values["metrics"]?.objectValue?[metric]?.intValue
        {
          copy.value = max(0, metricValue)
        } else if let score = values["score"]?.intValue {
          copy.value = max(0, score)
        }
        if mode == .composite, let seconds = values["time"]?.numberValue {
          copy.timeMilliseconds = Self.milliseconds(seconds)
        }
      }
    }

    guard phase != .success, phase != .failure else { return copy }
    copy.phase = copy.phase(for: snapshot)
    return copy
  }

  func settled(won: Bool, runtimeMilliseconds: Int?) -> ChallengeHUDState {
    var copy = self
    copy.phase = won ? .success : (mode == .timer ? .expired : .failure)
    if copy.phase == .expired {
      copy.value = max(copy.value, runtimeMilliseconds ?? target)
    }
    return copy
  }

  var progress: Double {
    guard target > 0 else { return 0 }
    return min(1, Double(value) / Double(target))
  }

  var valueText: String {
    mode == .timer ? Self.clock(milliseconds: value) : value.formatted()
  }

  var targetText: String {
    mode == .timer ? Self.clock(milliseconds: target) : target.formatted()
  }

  var timeText: String { Self.clock(milliseconds: timeMilliseconds) }

  var timeLimitText: String { Self.clock(milliseconds: timeLimitMilliseconds) }

  private func phase(for snapshot: [String: JSONValue]?) -> Phase {
    if let outcome = Self.objectiveOutcome(snapshot) {
      return outcome ? .success : (mode == .timer ? .expired : .failure)
    }

    switch mode {
    case .composite:
      if timeLimitMilliseconds > 0,
        timeLimitMilliseconds - timeMilliseconds <= 10_000
      {
        return .warning
      }
      return .progress
    case .timer:
      if target > 0, value >= target { return .expired }
      if Self.isComplete(snapshot) { return .success }
      if target > 0, target - value <= 10_000 { return .warning }
      return .progress
    case .score:
      if target > 0, value >= target { return .success }
      if Self.isComplete(snapshot) { return .failure }
      if target > 0, Double(value) / Double(target) >= 0.9 { return .nearTarget }
      return .progress
    }
  }

  private static func objectiveOutcome(_ snapshot: [String: JSONValue]?) -> Bool? {
    guard let snapshot else { return nil }
    let challenge = snapshot["challenge"]?.objectValue ?? [:]
    if case .bool(let value) = challenge["met"] { return value }
    if case .bool(let value) = challenge["won"] { return value }
    if case .bool(let value) = snapshot["won"] { return value }

    let outcome =
      challenge["objective_outcome"]?.stringValue
      ?? challenge["outcome"]?.stringValue
      ?? snapshot["outcome"]?.stringValue
    switch outcome {
    case "won", "win", "met", "challenge_win":
      return true
    case "lost", "loss", "missed":
      return false
    default:
      return nil
    }
  }

  private static func isComplete(_ snapshot: [String: JSONValue]?) -> Bool {
    guard let status = snapshot?["status"]?.stringValue else { return false }
    return ["ended", "completed", "finished"].contains(status)
  }

  private static func milliseconds(_ seconds: Double) -> Int {
    guard seconds.isFinite else { return 0 }
    return max(0, Int((seconds * 1_000).rounded(.down)))
  }

  private static func clock(milliseconds: Int) -> String {
    let seconds = max(0, milliseconds) / 1_000
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}

extension JSONValue {
  nonisolated fileprivate var numberValue: Double? {
    guard case .number(let value) = self, value.isFinite else { return nil }
    return value
  }
}
