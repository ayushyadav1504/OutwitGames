import GoogleMobileAds

@MainActor
final class GoogleInterstitialAdService: NSObject, InterstitialAdServing {
  private let configuration: GoogleMobileAdsConfiguration
  private let consent: any AdConsentServicing

  private var ad: InterstitialAd?
  private var isLoading = false
  private var initialized = false
  private var impressionRecorded = false
  private var presentationContinuation: CheckedContinuation<Bool, Never>?

  init(
    configuration: GoogleMobileAdsConfiguration,
    consent: any AdConsentServicing
  ) {
    self.configuration = configuration
    self.consent = consent
  }

  var isReady: Bool { ad != nil }

  func load() async {
    await initialize()
    guard initialized, consent.canRequestAds, ad == nil, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      let loaded = try await InterstitialAd.load(
        with: configuration.interstitialAdUnitID,
        request: Request()
      )
      loaded.fullScreenContentDelegate = self
      ad = loaded
    } catch {
      ad = nil
    }
  }

  func show() async -> Bool {
    guard presentationContinuation == nil, let ad else { return false }
    self.ad = nil
    impressionRecorded = false

    return await withCheckedContinuation { continuation in
      presentationContinuation = continuation
      ad.present(from: nil)
    }
  }

  private func initialize() async {
    guard !initialized, consent.canRequestAds else { return }
    initialized = true
    await MobileAds.shared.start()
  }

  private func finishPresentation() {
    let continuation = presentationContinuation
    presentationContinuation = nil
    continuation?.resume(returning: impressionRecorded)
  }
}

extension GoogleInterstitialAdService: FullScreenContentDelegate {
  func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
    impressionRecorded = true
  }

  func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
    finishPresentation()
  }

  func ad(
    _ ad: FullScreenPresentingAd,
    didFailToPresentFullScreenContentWithError error: any Error
  ) {
    finishPresentation()
  }
}
