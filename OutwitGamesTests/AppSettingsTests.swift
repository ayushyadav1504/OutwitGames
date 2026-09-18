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

    settings.setLanguage(.hindi)

    let restoredSettings = AppSettings(defaults: defaults)
    #expect(restoredSettings.language == .hindi)
    #expect(restoredSettings.locale.identifier == "hi_IN")
  }
}
