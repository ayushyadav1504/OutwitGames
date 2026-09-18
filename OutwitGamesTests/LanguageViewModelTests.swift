import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct LanguageViewModelTests {
  @Test
  func continuingPersistsSelectionAndStartsOnboarding() throws {
    let suiteName = "LanguageViewModelTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)
    let coordinator = AppCoordinator(root: .language)
    let viewModel = LanguageViewModel(settings: settings, coordinator: coordinator)

    #expect(viewModel.selectedLanguage == .english)

    viewModel.select(.hindi)
    viewModel.continueFlow()

    #expect(settings.language == .hindi)
    #expect(defaults.string(forKey: "app.language") == "hi")
    #expect(coordinator.root == .onboarding)
    #expect(coordinator.path.isEmpty)
  }
}
