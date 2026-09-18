import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct AppSettingsTests {
  @Test
  func persistsTheSelectedLanguage() throws {
    let suiteName = "AppSettingsTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)
    #expect(settings.language == nil)
    #expect(settings.locale.identifier == "en_IN")
    #expect(!settings.hasSeenIntroduction)
    #expect(!settings.isOnboardingComplete)

    settings.setLanguage(.hindi)
    settings.markIntroductionSeen()
    settings.markOnboardingComplete()

    let restoredSettings = AppSettings(defaults: defaults)
    #expect(restoredSettings.language == .hindi)
    #expect(restoredSettings.locale.identifier == "hi_IN")
    #expect(restoredSettings.hasSeenIntroduction)
    #expect(restoredSettings.isOnboardingComplete)
  }
}
