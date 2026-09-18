import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
  @ObservationIgnored private let defaults: UserDefaults

  private(set) var language: AppLanguage?

  var locale: Locale {
    language?.locale ?? AppLanguage.english.locale
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    language = defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:))
  }

  func setLanguage(_ language: AppLanguage) {
    self.language = language
    defaults.set(language.rawValue, forKey: Key.language)
  }

  private enum Key {
    static let language = "app.language"
  }
}
