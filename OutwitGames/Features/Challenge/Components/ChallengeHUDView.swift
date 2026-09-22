import SwiftUI

struct ChallengeHUDView: View {
  let challengeTitle: String
  let hud: ChallengeHUDState
  let onClose: () -> Void

  var body: some View {
    ZStack(alignment: .top) {
      ChallengeHUDShell(phase: hud.phase)

      HStack(alignment: .top, spacing: 8) {
        exitKey
        metrics
        reward
      }
      .padding(.horizontal, 13)
      .padding(.top, 10)
    }
    .frame(height: 121)
    // The hosted game HUD intentionally keeps a fixed compact scale. Its full
    // meaning is exposed as one accessibility element below.
    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(verbatim: challengeTitle))
    .accessibilityIdentifier("challenge-hud")
  }

  private var exitKey: some View {
    Button(action: onClose) {
      Image(systemName: "xmark")
        .font(.system(size: 18, weight: .black))
        .foregroundStyle(Color(red: 143 / 255, green: 106 / 255, blue: 69 / 255))
        .frame(width: 48, height: 74)
        .background(
          LinearGradient(
            colors: [.white, Color(red: 1, green: 0.92, blue: 0.77)],
            startPoint: .top,
            endPoint: .bottom
          ),
          in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 17, style: .continuous)
            .stroke(.white.opacity(0.9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.22), radius: 2, y: 4)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("challenge.close")
    .accessibilityIdentifier("challenge-close")
  }

  private var metrics: some View {
    VStack(spacing: 5) {
      if hud.phase == .success || hud.phase == .failure || hud.phase == .expired {
        resultBanner
      } else if hud.mode == .composite {
        HStack(spacing: 4) {
          metricColumn(label: currentLabel, value: hud.valueText, emphasized: true)
          divider
          metricColumn(label: "challenge.hud.target", value: hud.targetText)
          divider
          metricColumn(label: "challenge.hud.time", value: hud.timeText)
        }
      } else {
        HStack(spacing: 8) {
          metricColumn(label: currentLabel, value: hud.valueText, emphasized: true)
          divider
          metricColumn(label: targetLabel, value: hud.targetText)
        }
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(OutwitColors.ink)
          Capsule()
            .fill(progressColor)
            .frame(width: max(6, proxy.size.width * hud.progress))
            .padding(2)
            .animation(.easeOut(duration: 0.3), value: hud.progress)
        }
      }
      .frame(height: 11)
      .accessibilityHidden(true)
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 7)
    .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82)
    .background(
      LinearGradient(
        colors: [Color(red: 1, green: 0.99, blue: 0.95), Color(red: 1, green: 0.88, blue: 0.69)],
        startPoint: .top,
        endPoint: .bottom
      ),
      in: RoundedRectangle(cornerRadius: 21, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 21, style: .continuous)
        .stroke(.white.opacity(0.92), lineWidth: 2)
    )
    .shadow(color: .black.opacity(0.2), radius: 2, y: 4)
  }

  private var reward: some View {
    VStack(spacing: 0) {
      Image("OutwitCoin3D")
        .resizable()
        .scaledToFit()
        .frame(width: hud.phase == .success || isLoss ? 49 : 39, height: 49)
        .saturation(isLoss ? 0.3 : 1)
        .scaleEffect(hud.phase == .success ? 1.08 : 1)
        .animation(.spring(response: 0.38, dampingFraction: 0.7), value: hud.phase)

      if isLoss {
        Text("challenge.hud.no_reward")
          .foregroundStyle(OutwitColors.action)
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(hud.rewardCoins, format: .number)
            .foregroundStyle(OutwitColors.action)
          Text("challenge.hud.coins")
            .font(.custom("NunitoSans-Bold", fixedSize: 10))
            .foregroundStyle(OutwitColors.ink)
        }
      }
    }
    .font(.custom("NunitoSans-ExtraBold", fixedSize: 16))
    .frame(width: 64, height: 82)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("challenge.reward")
    .accessibilityValue(
      isLoss ? Text("challenge.hud.no_reward") : Text(hud.rewardCoins.formatted()))
  }

  private var resultBanner: some View {
    HStack(spacing: 8) {
      Image(hud.phase == .success ? "OutwitCoin3D" : "ChallengeNearMissSad")
        .resizable()
        .scaledToFit()
        .frame(width: 38, height: 38)
      VStack(alignment: .leading, spacing: 0) {
        Text(hud.phase == .success ? "challenge.hud.won" : "challenge.hud.missed")
          .font(.custom("NunitoSans-ExtraBold", fixedSize: 16))
          .foregroundStyle(OutwitColors.ink)
        Text(hud.phase == .success ? "challenge.hud.won_detail" : "challenge.hud.missed_detail")
          .font(.custom("NunitoSans-Bold", fixedSize: 11))
          .foregroundStyle(OutwitColors.mutedInk)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, minHeight: 52)
    .background(
      hud.phase == .success ? OutwitColors.redTint : Color(red: 0.95, green: 0.91, blue: 0.92),
      in: RoundedRectangle(cornerRadius: 15, style: .continuous)
    )
    .transition(.scale(scale: 0.94).combined(with: .opacity))
  }

  private func metricColumn(
    label: LocalizedStringKey,
    value: String,
    emphasized: Bool = false
  ) -> some View {
    VStack(spacing: -1) {
      Text(label)
        .font(.custom("NunitoSans-Bold", fixedSize: 10))
        .foregroundStyle(emphasized ? phaseColor : OutwitColors.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(verbatim: value)
        .font(.custom("NunitoSans-ExtraBold", fixedSize: hud.mode == .composite ? 24 : 31))
        .monospacedDigit()
        .foregroundStyle(emphasized ? phaseColor : OutwitColors.action)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    .frame(maxWidth: .infinity)
  }

  private var divider: some View {
    Capsule()
      .fill(Color(red: 0.65, green: 0.47, blue: 0.3).opacity(0.45))
      .frame(width: 1.5, height: 22)
  }

  private var currentLabel: LocalizedStringKey {
    if hud.mode == .timer { return "challenge.hud.your_time" }
    if hud.phase == .nearTarget { return "challenge.hud.almost" }
    return "challenge.hud.your_score"
  }

  private var targetLabel: LocalizedStringKey {
    hud.mode == .timer ? "challenge.hud.finish_under" : "challenge.hud.target"
  }

  private var isLoss: Bool { hud.phase == .failure || hud.phase == .expired }

  private var phaseColor: Color {
    switch hud.phase {
    case .failure, .expired:
      Color(red: 0.72, green: 0.16, blue: 0.2)
    default:
      OutwitColors.action
    }
  }

  private var progressColor: Color { isLoss ? OutwitColors.mutedInk : OutwitColors.action }
}

private struct ChallengeHUDShell: View {
  let phase: ChallengeHUDState.Phase

  var body: some View {
    ZStack(alignment: .top) {
      LinearGradient(
        colors: [Color(red: 0.47, green: 0.04, blue: 0.09), OutwitColors.red],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 94)

      ChallengeHUDWave()
        .fill(
          LinearGradient(
            colors: [OutwitColors.red, Color(red: 0.56, green: 0.02, blue: 0.09)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(height: 44)
        .offset(y: 76)
        .shadow(color: .black.opacity(0.3), radius: 7, y: 7)
    }
    .saturation((phase == .failure || phase == .expired) ? 0.55 : 1)
    .animation(.easeOut(duration: 0.3), value: phase)
  }
}

private struct ChallengeHUDWave: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 0, y: rect.height * 0.2))
    path.addCurve(
      to: CGPoint(x: rect.width * 0.35, y: rect.height * 0.42),
      control1: CGPoint(x: rect.width * 0.12, y: rect.height * 0.05),
      control2: CGPoint(x: rect.width * 0.23, y: rect.height * 0.62)
    )
    path.addCurve(
      to: CGPoint(x: rect.width * 0.7, y: rect.height * 0.28),
      control1: CGPoint(x: rect.width * 0.47, y: rect.height * 0.15),
      control2: CGPoint(x: rect.width * 0.57, y: rect.height * 0.5)
    )
    path.addCurve(
      to: CGPoint(x: rect.width, y: rect.height * 0.24),
      control1: CGPoint(x: rect.width * 0.82, y: rect.height * 0.02),
      control2: CGPoint(x: rect.width * 0.91, y: rect.height * 0.45)
    )
    path.addLine(to: CGPoint(x: rect.width, y: 0))
    path.addLine(to: .zero)
    path.closeSubpath()
    return path
  }
}
