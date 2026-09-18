import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
  case english = "en"
  case hindi = "hi"

  var id: Self { self }

  var locale: Locale {
    Locale(identifier: "\(rawValue)_IN")
  }
}
