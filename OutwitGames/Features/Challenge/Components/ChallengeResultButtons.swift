import SwiftUI

struct ChallengeWatchAdButton: View {
  let title: LocalizedStringKey
  let isLoading: Bool
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        HStack {
          Image("ChallengeWatchAd")
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 52)
            .padding(.leading, 6)
          Spacer()
        }

        if isLoading {
          ProgressView()
            .tint(.white)
        } else {
          Text(title)
            .font(.custom("NunitoSans-Bold", size: 18, relativeTo: .headline))
            .foregroundStyle(isEnabled ? .white : OutwitColors.mutedInk)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
      .background(
        isEnabled
          ? AnyShapeStyle(
            LinearGradient(
              colors: [OutwitColors.red, OutwitColors.action],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          : AnyShapeStyle(OutwitColors.paleBorder),
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .shadow(color: isEnabled ? OutwitColors.actionPressed : .clear, radius: 0, y: 6)
      .shadow(color: isEnabled ? OutwitColors.action.opacity(0.22) : .clear, radius: 14, y: 10)
    }
    .buttonStyle(ChallengePressedButtonStyle())
    .disabled(!isEnabled || isLoading)
  }
}

struct ChallengeSecondaryButton: View {
  let title: String
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(verbatim: title)
        .font(.custom("NunitoSans-Bold", size: 18, relativeTo: .headline))
        .foregroundStyle(isEnabled ? .white : OutwitColors.mutedInk)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
          isEnabled ? OutwitColors.ink : OutwitColors.paleBorder,
          in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: isEnabled ? .black.opacity(0.45) : .clear, radius: 0, y: 4)
        .shadow(color: isEnabled ? .black.opacity(0.14) : .clear, radius: 12, y: 8)
    }
    .buttonStyle(ChallengePressedButtonStyle(distance: 3))
    .disabled(!isEnabled)
  }
}

private struct ChallengePressedButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var distance: CGFloat = 4

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .offset(y: configuration.isPressed && !reduceMotion ? distance : 0)
      .animation(
        reduceMotion ? nil : .easeOut(duration: 0.09),
        value: configuration.isPressed
      )
  }
}
