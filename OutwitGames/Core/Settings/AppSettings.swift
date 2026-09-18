import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
  @ObservationIgnored private let defaults: UserDefaults

  private(set) var language: AppLanguage?
  private(set) var hasSeenIntroduction: Bool
  private(set) var isOnboardingComplete: Bool

  var locale: Locale {
    language?.locale ?? AppLanguage.english.locale
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    language = defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:))
    hasSeenIntroduction = defaults.bool(forKey: Key.hasSeenIntroduction)
    isOnboardingComplete = defaults.bool(forKey: Key.isOnboardingComplete)
  }

  func setLanguage(_ language: AppLanguage) {
    self.language = language
    defaults.set(language.rawValue, forKey: Key.language)
  }

  func markIntroductionSeen() {
    hasSeenIntroduction = true
    defaults.set(true, forKey: Key.hasSeenIntroduction)
  }

  func markOnboardingComplete() {
    isOnboardingComplete = true
    defaults.set(true, forKey: Key.isOnboardingComplete)
  }

  private enum Key {
    static let language = "app.language"
    static let hasSeenIntroduction = "onboarding.introduction_seen"
    static let isOnboardingComplete = "onboarding.complete"
  }
}
