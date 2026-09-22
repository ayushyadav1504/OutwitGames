import SwiftUI

struct ChallengeMultiplierView: View {
  private enum Phase: Equatable {
    case ready
    case spinning
    case reaction
    case result
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var rotation = 0.0
  @State private var phase = Phase.ready
  @State private var runTask: Task<Void, Never>?

  let data: ChallengeMultiplierViewData
  let onContinue: () -> Void
  let onSettled: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      (Text("challenge.multiplier.title_prefix")
        + Text("challenge.multiplier.title_accent").foregroundColor(OutwitColors.action))
        .font(.custom("NunitoSans-ExtraBold", size: 30, relativeTo: .title))
        .tracking(-1)
        .foregroundStyle(OutwitColors.ink)

      Text("challenge.multiplier.subtitle")
        .font(.custom("NunitoSans-SemiBold", size: 13, relativeTo: .subheadline))
        .foregroundStyle(OutwitColors.mutedInk)
        .padding(.top, 2)

      wheel
        .padding(.top, 8)

      resultZone
        .frame(height: 112)

      Spacer(minLength: 8)

      spinButton
        .frame(maxWidth: 320)
    }
    .padding(.horizontal, 18)
    .padding(.top, 18)
    .padding(.bottom, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(OutwitColors.softWhite.ignoresSafeArea())
    .sensoryFeedback(.selection, trigger: Int(rotation / 45))
    .sensoryFeedback(.success, trigger: phase == .reaction)
    .onDisappear {
      runTask?.cancel()
      runTask = nil
    }
  }

  private var wheel: some View {
    ZStack(alignment: .top) {
      ZStack {
        ChallengeWheelFace(data: data)
          .rotationEffect(.degrees(rotation))
          .shadow(color: .black.opacity(0.25), radius: 14, y: 9)

        Circle()
          .fill(.white)
          .frame(width: 126, height: 126)
          .overlay(Circle().stroke(OutwitColors.ink, lineWidth: 4))
          .overlay(wheelCenter)
      }
      .frame(width: 288, height: 288)
      .padding(.top, 9)

      ChallengeWheelPointer()
        .fill(Color(red: 0.04, green: 0.6, blue: 0.59))
        .overlay(ChallengeWheelPointer().stroke(OutwitColors.ink, lineWidth: 4))
        .frame(width: 34, height: 34)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 4)
    }
    .frame(width: 320, height: 320)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(data.segments.map(\.label).joined(separator: ", ")))
  }

  @ViewBuilder
  private var wheelCenter: some View {
    if phase == .reaction || phase == .result {
      VStack(spacing: -3) {
        Image(data.reactionImageName)
          .resizable()
          .scaledToFit()
          .frame(width: data.bonusCoins > 0 ? 58 : 48, height: data.bonusCoins > 0 ? 58 : 48)
        Text(
          data.bonusCoins > 0
            ? "+\(data.bonusCoins.formatted())" : String(localized: "challenge.multiplier.no_bonus")
        )
        .font(.custom("NunitoSans-ExtraBold", fixedSize: 15))
        .foregroundStyle(OutwitColors.action)
        Text("\(data.totalCoins.formatted()) \(String(localized: "challenge.hud.coins"))")
          .font(.custom("NunitoSans-Bold", fixedSize: 10))
          .foregroundStyle(OutwitColors.mutedInk)
      }
      .transition(.scale(scale: 0.72).combined(with: .opacity))
    } else {
      VStack(spacing: 0) {
        Image("OutwitCoin3D")
          .resizable()
          .scaledToFit()
          .frame(width: 52, height: 52)
        Text("challenge.multiplier.current_reward")
          .font(.custom("NunitoSans-Bold", fixedSize: 9))
          .foregroundStyle(OutwitColors.mutedInk)
        Text("\(data.baseCoins.formatted()) \(String(localized: "challenge.hud.coins"))")
          .font(.custom("NunitoSans-ExtraBold", fixedSize: 16))
          .foregroundStyle(OutwitColors.action)
      }
      .transition(.scale(scale: 0.72).combined(with: .opacity))
    }
  }

  @ViewBuilder
  private var resultZone: some View {
    switch phase {
    case .ready, .spinning:
      Color.clear
    case .reaction:
      VStack(spacing: 3) {
        Text(reactionTitle)
          .font(.custom("NunitoSans-ExtraBold", size: 23, relativeTo: .title2))
          .foregroundStyle(data.bonusCoins > 0 ? OutwitColors.action : OutwitColors.ink)
        Text(reactionDetail)
          .font(.custom("NunitoSans-SemiBold", size: 13, relativeTo: .subheadline))
          .foregroundStyle(OutwitColors.mutedInk)
      }
      .multilineTextAlignment(.center)
      .transition(.scale(scale: 0.86).combined(with: .opacity))
    case .result:
      VStack(spacing: -5) {
        HStack(spacing: 4) {
          Image("OutwitCoin3D")
            .resizable()
            .scaledToFit()
            .frame(width: 82, height: 82)
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(data.totalCoins, format: .number)
              .font(.custom("NunitoSans-ExtraBold", size: 54, relativeTo: .largeTitle))
              .tracking(-2)
              .foregroundStyle(OutwitColors.action)
            Text("challenge.hud.coins")
              .font(.custom("NunitoSans-ExtraBold", size: 27, relativeTo: .title))
              .foregroundStyle(OutwitColors.ink)
          }
        }
        Text("challenge.multiplier.ready_collect")
          .font(.custom("NunitoSans-SemiBold", size: 12, relativeTo: .caption))
          .foregroundStyle(OutwitColors.mutedInk)
      }
      .transition(.scale(scale: 0.78).combined(with: .opacity))
    }
  }

  private var spinButton: some View {
    Button(action: beginSpin) {
      Text(spinButtonTitle)
        .font(.custom("NunitoSans-ExtraBold", size: 16, relativeTo: .headline))
        .foregroundStyle(phase == .ready ? .white : OutwitColors.mutedInk)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(
          phase == .ready
            ? AnyShapeStyle(
              LinearGradient(
                colors: [OutwitColors.red, OutwitColors.action],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            : AnyShapeStyle(Color(red: 0.89, green: 0.85, blue: 0.86)),
          in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: phase == .ready ? OutwitColors.actionPressed : .clear, radius: 0, y: 5)
    }
    .buttonStyle(.plain)
    .disabled(phase != .ready)
  }

  private var spinButtonTitle: LocalizedStringKey {
    switch phase {
    case .ready: "challenge.multiplier.spin"
    case .spinning: "challenge.multiplier.spinning"
    case .reaction, .result: "challenge.multiplier.spin_complete"
    }
  }

  private var reactionTitle: LocalizedStringKey {
    switch data.bonusCoins {
    case ...0: "challenge.multiplier.no_extra"
    case 1: "challenge.multiplier.little_extra"
    case 2: "challenge.multiplier.nice_boost"
    default: "challenge.multiplier.great_spin"
    }
  }

  private var reactionDetail: String {
    if data.bonusCoins <= 0 {
      return String(localized: "challenge.multiplier.reward_safe")
    }
    return data.isDoubled
      ? String(localized: "challenge.multiplier.reward_doubled")
      : String(localized: "challenge.multiplier.reward_grew")
  }

  private func beginSpin() {
    guard phase == .ready else { return }
    runTask?.cancel()
    runTask = Task { @MainActor in
      phase = .spinning
      if reduceMotion {
        rotation = data.landingRotationDegrees.truncatingRemainder(dividingBy: 360)
      } else {
        withAnimation(.timingCurve(0.12, 0.72, 0.12, 1, duration: 3.4)) {
          rotation = data.landingRotationDegrees
        }
        try? await Task.sleep(for: .seconds(3.4))
        guard !Task.isCancelled else { return }
      }

      withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) { phase = .reaction }
      onSettled()
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 850))
      guard !Task.isCancelled else { return }
      withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) { phase = .result }
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 900 : 1_500))
      guard !Task.isCancelled else { return }
      onContinue()
    }
  }
}

private struct ChallengeWheelFace: View {
  let data: ChallengeMultiplierViewData

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let radius = min(size.width, size.height) / 2
      let innerRadius = radius * 0.44
      let sweep = 360 / Double(max(1, data.segments.count))

      for (index, segment) in data.segments.enumerated() {
        let start = Double(index) * sweep - 90 - sweep / 2
        let end = start + sweep
        var path = Path()
        path.addArc(
          center: center,
          radius: radius,
          startAngle: .degrees(start),
          endAngle: .degrees(end),
          clockwise: false
        )
        path.addArc(
          center: center,
          radius: innerRadius,
          startAngle: .degrees(end),
          endAngle: .degrees(start),
          clockwise: true
        )
        path.closeSubpath()
        context.fill(path, with: .color(Color(outwitHex: segment.colorHex, index: index)))
        context.stroke(path, with: .color(OutwitColors.softWhite), lineWidth: 2)

        let angle = Angle.degrees(Double(index) * sweep - 90).radians
        let point = CGPoint(
          x: center.x + cos(angle) * radius * 0.72,
          y: center.y + sin(angle) * radius * 0.72
        )
        context.draw(
          Text(verbatim: segment.label)
            .font(.custom("NunitoSans-ExtraBold", fixedSize: 15))
            .foregroundStyle(.white),
          at: point,
          anchor: .center
        )
      }

      context.stroke(
        Path(ellipseIn: CGRect(origin: .zero, size: size)),
        with: .color(OutwitColors.ink),
        lineWidth: 3
      )
    }
  }
}

private struct ChallengeWheelPointer: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.closeSubpath()
    return path
  }
}

extension Color {
  fileprivate init(outwitHex raw: String, index: Int) {
    let value = raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    if value.count == 6, let number = UInt64(value, radix: 16) {
      self.init(
        red: Double((number >> 16) & 0xFF) / 255,
        green: Double((number >> 8) & 0xFF) / 255,
        blue: Double(number & 0xFF) / 255
      )
      return
    }
    let fallbacks: [Color] = [OutwitColors.action, .orange, .purple, .blue, .green]
    self = fallbacks[index % fallbacks.count]
  }
}
