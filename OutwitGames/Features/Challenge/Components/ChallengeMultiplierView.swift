import SwiftUI

struct ChallengeMultiplierView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var rotation = 0.0
  @State private var isSettled = false

  let data: ChallengeMultiplierViewData
  let onContinue: () -> Void
  let onSettled: () -> Void

  var body: some View {
    VStack(spacing: OutwitSpacing.x4) {
      Text("challenge.multiplier.title")
        .font(OutwitTypography.headlineLarge)
        .foregroundStyle(OutwitColors.ink)
        .multilineTextAlignment(.center)

      ZStack(alignment: .top) {
        wheel
          .rotationEffect(.degrees(rotation))
          .padding(.top, OutwitSpacing.x3)

        Image(systemName: "arrowtriangle.down.fill")
          .font(.system(size: 34, weight: .black))
          .foregroundStyle(OutwitColors.ink)
          .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
      }
      .frame(width: 280, height: 300)

      VStack(spacing: OutwitSpacing.x1) {
        Text("challenge.multiplier.total")
          .font(OutwitTypography.body)
          .foregroundStyle(OutwitColors.mutedInk)
        HStack(spacing: OutwitSpacing.x2) {
          Image("TutorialCoin")
            .resizable()
            .scaledToFit()
            .frame(width: 34, height: 34)
          Text(data.totalCoins, format: .number)
            .font(OutwitTypography.headlineLarge)
            .contentTransition(.numericText())
        }
        .foregroundStyle(OutwitColors.ink)
      }
      .opacity(isSettled ? 1 : 0)

      Button("challenge.result.collect", action: onContinue)
        .buttonStyle(.outwitPrimary)
        .frame(maxWidth: 340)
        .disabled(!isSettled)
        .opacity(isSettled ? 1 : 0.55)
    }
    .padding(OutwitSpacing.pageGutter)
    .sensoryFeedback(.success, trigger: isSettled)
    .task(id: data.selectedIndex) { await spin() }
    .accessibilityElement(children: .contain)
  }

  private var wheel: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let radius = min(size.width, size.height) / 2
      let sweep = 360 / Double(max(1, data.segments.count))

      for (index, segment) in data.segments.enumerated() {
        let start = Double(index) * sweep - 90
        let end = start + sweep
        var path = Path()
        path.move(to: center)
        path.addArc(
          center: center,
          radius: radius,
          startAngle: .degrees(start),
          endAngle: .degrees(end),
          clockwise: false
        )
        path.closeSubpath()
        context.fill(path, with: .color(Color(outwitHex: segment.colorHex, index: index)))

        let angle = Angle.degrees(start + sweep / 2).radians
        let point = CGPoint(
          x: center.x + cos(angle) * radius * 0.62,
          y: center.y + sin(angle) * radius * 0.62
        )
        context.draw(
          Text(verbatim: segment.label)
            .font(OutwitTypography.label)
            .foregroundStyle(.white),
          at: point,
          anchor: .center
        )
      }
    }
    .frame(width: 260, height: 260)
    .overlay(Circle().stroke(.white, lineWidth: 5))
    .shadow(color: .black.opacity(0.18), radius: 12, y: 7)
    .accessibilityHidden(true)
  }

  private func spin() async {
    rotation = 0
    isSettled = false
    if reduceMotion {
      rotation = data.landingRotationDegrees.truncatingRemainder(dividingBy: 360)
    } else {
      withAnimation(.timingCurve(0.12, 0.72, 0.12, 1, duration: 3.4)) {
        rotation = data.landingRotationDegrees
      }
      try? await Task.sleep(for: .seconds(3.4))
      guard !Task.isCancelled else { return }
    }
    isSettled = true
    onSettled()
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
