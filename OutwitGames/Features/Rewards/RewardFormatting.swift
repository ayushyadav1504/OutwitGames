import Foundation

nonisolated enum RewardFormatting {
  static func value(cents: Int, currency: String, locale: Locale) -> String {
    let safeCents = max(cents, 0)
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    formatter.locale = locale
    formatter.minimumFractionDigits = safeCents.isMultiple(of: 100) ? 0 : 2
    formatter.maximumFractionDigits = 2
    let amount = Decimal(safeCents) / 100
    return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
  }

  static func merchant(from name: String, value: String) -> String {
    name.replacingOccurrences(of: value, with: "")
      .split(whereSeparator: \Character.isWhitespace)
      .joined(separator: " ")
  }

  static func maskedCode(_ code: String) -> String {
    guard code.count > 9 else { return code }
    return "\(code.prefix(5))••••-\(code.suffix(4))"
  }
}
