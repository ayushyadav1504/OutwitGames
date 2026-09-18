import SwiftUI

enum OutwitTypography {
  static let headlineLarge = Font.custom(
    "NunitoSans-ExtraBold",
    size: 32,
    relativeTo: .largeTitle
  )
  static let headlineSmall = Font.custom(
    "NunitoSans-Bold",
    size: 20,
    relativeTo: .title3
  )
  static let body = Font.custom(
    "NunitoSans-Regular",
    size: 16,
    relativeTo: .body
  )
  static let bodyEmphasized = Font.custom(
    "NunitoSans-SemiBold",
    size: 16,
    relativeTo: .body
  )
  static let bodySmall = Font.custom(
    "NunitoSans-Regular",
    size: 14,
    relativeTo: .subheadline
  )
  static let label = Font.custom(
    "NunitoSans-Bold",
    size: 16,
    relativeTo: .headline
  )
}
