import SwiftUI

struct OutwitPrimaryButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(OutwitTypography.label)
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, minHeight: 52)
      .padding(.horizontal, OutwitSpacing.x6)
      .background(backgroundColor(configuration), in: buttonShape)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .animation(
        reduceMotion ? nil : .easeOut(duration: 0.12),
        value: configuration.isPressed
      )
  }

  private var buttonShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: OutwitRadius.button, style: .continuous)
  }

  private func backgroundColor(_ configuration: Configuration) -> Color {
    guard isEnabled else { return OutwitColors.paleBorder }
    return configuration.isPressed ? OutwitColors.actionPressed : OutwitColors.action
  }
}

extension ButtonStyle where Self == OutwitPrimaryButtonStyle {
  static var outwitPrimary: Self { OutwitPrimaryButtonStyle() }
}
