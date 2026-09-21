import UserMessagingPlatform

@MainActor
final class GoogleAdConsentService: AdConsentServicing {
  var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

  var isPrivacyOptionsRequired: Bool {
    ConsentInformation.shared.privacyOptionsRequirementStatus == .required
  }

  func prepare() async {
    do {
      try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
      try await ConsentForm.loadAndPresentIfRequired(from: nil)
    } catch {
      // A previous valid consent choice may still allow ads after a refresh error.
    }
  }

  func presentPrivacyOptions() async throws {
    try await ConsentForm.presentPrivacyOptionsForm(from: nil)
  }
}
