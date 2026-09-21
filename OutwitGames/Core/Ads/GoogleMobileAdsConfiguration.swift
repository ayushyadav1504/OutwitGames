import Foundation

nonisolated struct GoogleMobileAdsConfiguration: Equatable, Sendable {
  let multiplierAdUnitID: String
  let retryAdUnitID: String

  static func bundled(in bundle: Bundle = .main) -> GoogleMobileAdsConfiguration? {
    guard
      let multiplier = value(
        named: "OUTWIT_REWARDED_MULTIPLIER_AD_UNIT_ID",
        in: bundle
      ),
      let retry = value(named: "OUTWIT_REWARDED_RETRY_AD_UNIT_ID", in: bundle)
    else {
      return nil
    }
    return GoogleMobileAdsConfiguration(
      multiplierAdUnitID: multiplier,
      retryAdUnitID: retry
    )
  }

  func adUnitID(for placement: RewardedAdPlacement) -> String {
    switch placement {
    case .multiplier:
      multiplierAdUnitID
    case .retry:
      retryAdUnitID
    }
  }

  private static func value(named key: String, in bundle: Bundle) -> String? {
    guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !value.contains("$(") else { return nil }
    return value
  }
}
