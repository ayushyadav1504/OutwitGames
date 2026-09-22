import GoogleMobileAds

@MainActor
final class GoogleRewardedAdService: NSObject, RewardedAdServing {
  private let configuration: GoogleMobileAdsConfiguration
  private let consent: any AdConsentServicing
  private let onImpression: @MainActor () -> Void

  private var ads: [RewardedAdPlacement: RewardedAd] = [:]
  private var loading: Set<RewardedAdPlacement> = []
  private var initialized = false
  private var earnedReward = false
  private var presentationContinuation: CheckedContinuation<RewardedAdOutcome, Never>?

  init(
    configuration: GoogleMobileAdsConfiguration,
    consent: any AdConsentServicing,
    onImpression: @escaping @MainActor () -> Void = {}
  ) {
    self.configuration = configuration
    self.consent = consent
    self.onImpression = onImpression
  }

  func initialize() async {
    guard !initialized, consent.canRequestAds else { return }
    initialized = true
    await MobileAds.shared.start()
  }

  func load(_ placement: RewardedAdPlacement) async {
    await initialize()
    guard initialized, consent.canRequestAds, ads[placement] == nil else { return }
    guard loading.insert(placement).inserted else {
      while loading.contains(placement) { await Task.yield() }
      return
    }
    defer { loading.remove(placement) }

    do {
      let ad = try await RewardedAd.load(
        with: configuration.adUnitID(for: placement),
        request: Request()
      )
      ad.fullScreenContentDelegate = self
      ads[placement] = ad
    } catch {
      ads[placement] = nil
    }
  }

  func show(
    _ placement: RewardedAdPlacement,
    userID: String,
    customData: String
  ) async -> RewardedAdOutcome {
    guard presentationContinuation == nil else { return .unavailable }
    if ads[placement] == nil { await load(placement) }
    guard let ad = ads.removeValue(forKey: placement) else { return .unavailable }

    let options = ServerSideVerificationOptions()
    options.userIdentifier = userID
    options.customRewardText = customData
    ad.serverSideVerificationOptions = options
    earnedReward = false

    let outcome = await withCheckedContinuation { continuation in
      presentationContinuation = continuation
      ad.present(from: nil) { [weak self] in
        self?.earnedReward = true
      }
    }
    Task { await load(placement) }
    return outcome
  }

  private func finishPresentation(with outcome: RewardedAdOutcome) {
    let continuation = presentationContinuation
    presentationContinuation = nil
    continuation?.resume(returning: outcome)
  }
}

extension GoogleRewardedAdService: FullScreenContentDelegate {
  func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
    onImpression()
  }

  func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
    finishPresentation(with: earnedReward ? .earned : .dismissed)
  }

  func ad(
    _ ad: FullScreenPresentingAd,
    didFailToPresentFullScreenContentWithError error: any Error
  ) {
    finishPresentation(with: .unavailable)
  }
}
