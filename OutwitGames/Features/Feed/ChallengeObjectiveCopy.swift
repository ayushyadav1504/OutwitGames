import Foundation

struct ChallengeObjectiveCopy: Equatable {
  struct Part: Equatable {
    let text: String
    let isHighlighted: Bool
  }

  let parts: [Part]
  var sentence: String { parts.map(\.text).joined() }
}

enum ChallengeObjectiveCopyBuilder {
  static func make(
    objective: ChallengeObjective,
    locale: Locale,
    depth: Int = 0
  ) -> ChallengeObjectiveCopy {
    guard depth < 16 else { return plain(localized("feed.objective.generic", locale)) }

    switch objective.type {
    case "composite":
      return composite(objective, locale: locale, depth: depth)
    case "min_score":
      return split(
        localized("feed.objective.min_score", locale),
        values: ["@value": formatCount(objective.target, locale: locale)]
      )
    case "time_limit":
      return split(
        localized("feed.objective.time_limit", locale),
        values: ["@value": formatClock(objective.maximumMilliseconds)]
      )
    case "survive_duration":
      return split(
        localized("feed.objective.survive", locale),
        values: ["@value": formatClock(objective.minimumMilliseconds)]
      )
    case "collect_count":
      return split(
        localized("feed.objective.collect", locale),
        values: [
          "@value": formatCount(objective.target, locale: locale),
          "@metric": humanized(objective.metric),
        ]
      )
    case "move_limit":
      return split(
        localized("feed.objective.move_limit", locale),
        values: [
          "@value": formatCount(objective.maximum ?? objective.target, locale: locale)
        ]
      )
    case "clear_all":
      return plain(localized("feed.objective.clear_all", locale))
    default:
      return plain(localized("feed.objective.generic", locale))
    }
  }

  private static func composite(
    _ objective: ChallengeObjective,
    locale: Locale,
    depth: Int
  ) -> ChallengeObjectiveCopy {
    guard
      let operation = objective.raw["op"]?.stringValue,
      ["all", "any"].contains(operation),
      let values = objective.raw["terms"]?.arrayValue,
      !values.isEmpty
    else {
      return plain(localized("feed.objective.generic", locale))
    }

    let terms = values.compactMap(\.objectValue).map(ChallengeObjective.init(raw:))
    guard terms.count == values.count else {
      return plain(localized("feed.objective.generic", locale))
    }

    let targetTerms = terms.filter { ["min_score", "collect_count"].contains($0.type) }
    let timerTerms = terms.filter { $0.type == "time_limit" }
    if operation == "all", terms.count == 2, let target = targetTerms.first,
      targetTerms.count == 1, let timer = timerTerms.first, timerTerms.count == 1
    {
      let key =
        target.type == "min_score"
        ? "feed.objective.timed_score"
        : "feed.objective.timed_collect"
      return split(
        localized(key, locale),
        values: [
          "@value": formatCount(target.target, locale: locale),
          "@time": formatClock(timer.maximumMilliseconds),
          "@metric": humanized(target.metric),
        ]
      )
    }

    let separator = localized(
      operation == "all" ? "feed.objective.and" : "feed.objective.or",
      locale
    )
    var parts: [ChallengeObjectiveCopy.Part] = []
    for (index, term) in terms.enumerated() {
      if index > 0 { parts.append(.init(text: separator, isHighlighted: false)) }
      let child = make(objective: term, locale: locale, depth: depth + 1)
      parts.append(contentsOf: child.parts)
    }
    return ChallengeObjectiveCopy(parts: parts)
  }

  private static func split(
    _ template: String,
    values: [String: String]
  ) -> ChallengeObjectiveCopy {
    let tokens = values.keys.sorted { $0.count > $1.count }
    var remaining = template[...]
    var parts: [ChallengeObjectiveCopy.Part] = []

    while let match = tokens.compactMap({ token -> (String, Range<Substring.Index>)? in
      guard let range = remaining.range(of: token) else { return nil }
      return (token, range)
    }).min(by: { $0.1.lowerBound < $1.1.lowerBound }) {
      let prefix = String(remaining[..<match.1.lowerBound])
      if !prefix.isEmpty { parts.append(.init(text: prefix, isHighlighted: false)) }
      parts.append(.init(text: values[match.0] ?? "", isHighlighted: true))
      remaining = remaining[match.1.upperBound...]
    }

    if !remaining.isEmpty { parts.append(.init(text: String(remaining), isHighlighted: false)) }
    return ChallengeObjectiveCopy(parts: parts)
  }

  private static func plain(_ value: String) -> ChallengeObjectiveCopy {
    ChallengeObjectiveCopy(parts: [.init(text: value, isHighlighted: false)])
  }

  private static func localized(_ key: String, _ locale: Locale) -> String {
    String(localized: String.LocalizationValue(key), bundle: .main, locale: locale)
  }

  private static func formatCount(_ value: Int?, locale: Locale) -> String {
    (value ?? 0).formatted(.number.grouping(.automatic).locale(locale))
  }

  private static func formatClock(_ milliseconds: Int?) -> String {
    let totalSeconds = Int((Double(milliseconds ?? 0) / 1_000).rounded())
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
  }

  private static func humanized(_ metric: String?) -> String {
    (metric ?? "").replacingOccurrences(of: "_", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
