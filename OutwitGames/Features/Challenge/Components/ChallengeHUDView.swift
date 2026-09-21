import SwiftUI

struct ChallengeHUDView: View {
  let challengeTitle: String
  let hud: ChallengeHUDState
  let onClose: () -> Void

  var body: some View {
    VStack(spacing: OutwitSpacing.x2) {
      HStack(spacing: OutwitSpacing.x3) {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 17, weight: .bold))
            .frame(width: 40, height: 40)
            .background(.white.opacity(0.16), in: Circle())
        }
        .accessibilityLabel("challenge.close")
        .accessibilityIdentifier("challenge-close")

        VStack(alignment: .leading, spacing: OutwitSpacing.x1) {
          if !challengeTitle.isEmpty {
            Text(verbatim: challengeTitle)
              .font(OutwitTypography.bodySmall)
              .lineLimit(1)
              .opacity(0.82)
          }

          HStack(alignment: .firstTextBaseline, spacing: OutwitSpacing.x1) {
            Text(verbatim: hud.valueText)
              .font(OutwitTypography.headlineSmall)
            Text(verbatim: "/ \(hud.targetText)")
              .font(OutwitTypography.bodySmall)
              .opacity(0.82)
          }
          .accessibilityLabel("challenge.progress")
          .accessibilityValue(Text(verbatim: "\(hud.valueText) / \(hud.targetText)"))
        }

        Spacer(minLength: OutwitSpacing.x2)

        Label(hud.rewardCoins.formatted(), systemImage: "circle.fill")
          .font(OutwitTypography.label)
          .symbolRenderingMode(.palette)
          .foregroundStyle(.white, .yellow)
          .accessibilityLabel("challenge.reward")
          .accessibilityValue(hud.rewardCoins.formatted())
      }

      ProgressView(value: hud.progress)
        .tint(.white)
        .accessibilityHidden(true)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, OutwitSpacing.x4)
    .padding(.top, OutwitSpacing.x2)
    .padding(.bottom, OutwitSpacing.x3)
    .background(OutwitColors.action)
  }
}
