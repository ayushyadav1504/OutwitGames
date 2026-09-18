import Observation

@MainActor
@Observable
final class LanguageViewModel {
  private let settings: AppSettings
  private let coordinator: AppCoordinator

  var selectedLanguage: AppLanguage

  init(settings: AppSettings, coordinator: AppCoordinator) {
    self.settings = settings
    self.coordinator = coordinator
    selectedLanguage = settings.language ?? .english
  }

  func select(_ language: AppLanguage) {
    selectedLanguage = language
  }

  func continueFlow() {
    settings.setLanguage(selectedLanguage)
    coordinator.reset(to: .onboarding)
  }
}
