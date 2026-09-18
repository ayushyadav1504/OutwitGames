import SwiftUI

struct TutorialHeader: View {
  var body: some View {
    HStack(spacing: 0) {
      Image("OutwitLogoPrimary")
        .resizable()
        .scaledToFit()
        .frame(width: 92)

      Spacer()

      HStack(spacing: 5) {
        TutorialCoin(size: 22, angle: -3)
        Text("onboarding.header.balance")
          .font(.custom("NunitoSans-ExtraBold", fixedSize: 13))
          .foregroundStyle(OutwitColors.ink)
      }
      .padding(.horizontal, 9)
      .frame(height: 34)
      .background(.white, in: Capsule())
      .overlay(Capsule().stroke(OutwitColors.paleBorder, lineWidth: 1))
      .shadow(color: OutwitColors.ink.opacity(0.08), radius: 6, y: 2)

      Image("TutorialAvatar")
        .resizable()
        .scaledToFill()
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .padding(.leading, 10)
    }
    .frame(width: 328, height: 44)
    .accessibilityHidden(true)
  }
}

struct TutorialActionButton: View {
  let title: LocalizedStringKey
  var showArrow = false
  var height: CGFloat = 52
  var fontSize: CGFloat = 18
  var cornerRadius: CGFloat = 16
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(title)
        if showArrow {
          Image(systemName: "chevron.right")
            .font(.system(size: fontSize - 1, weight: .bold))
            .accessibilityHidden(true)
        }
      }
      .font(.custom("NunitoSans-Bold", fixedSize: fontSize))
      .lineLimit(1)
      .minimumScaleFactor(0.72)
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
    }
    .buttonStyle(
      TutorialActionButtonStyle(height: height, cornerRadius: cornerRadius)
    )
  }
}

private struct TutorialActionButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let height: CGFloat
  let cornerRadius: CGFloat

  func makeBody(configuration: Configuration) -> some View {
    let isPressed = configuration.isPressed
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    configuration.label
      .background(
        LinearGradient(
          colors: [OutwitColors.red, OutwitColors.action],
          startPoint: .top,
          endPoint: .bottom
        ),
        in: shape
      )
      .shadow(
        color: OutwitColors.actionPressed,
        radius: 0,
        y: isPressed ? 1 : min(6, height * 0.12)
      )
      .shadow(
        color: OutwitColors.actionPressed.opacity(0.2),
        radius: isPressed ? 8 : 16,
        y: isPressed ? 4 : 10
      )
      .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1)
      .offset(y: isPressed && !reduceMotion ? min(5, height * 0.1) : 0)
      .animation(
        reduceMotion ? nil : .easeOut(duration: 0.12),
        value: isPressed
      )
  }
}
