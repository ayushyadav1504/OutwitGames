import SwiftUI

struct TutorialCoin: View {
  let size: CGFloat
  var angle: Double = 0

  var body: some View {
    Image("TutorialCoin")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .rotationEffect(.degrees(angle))
      .accessibilityHidden(true)
  }
}

struct TutorialAccentBurst: View {
  var body: some View {
    Canvas { context, size in
      let origin = CGPoint(x: size.width * 0.9, y: size.height * 0.96)
      let ends = [
        CGPoint(x: size.width * 0.04, y: size.height * 0.9),
        CGPoint(x: size.width * 0.14, y: size.height * 0.5),
        CGPoint(x: size.width * 0.4, y: size.height * 0.1),
        CGPoint(x: size.width * 0.82, y: 0),
      ]

      for end in ends {
        let start = CGPoint(
          x: origin.x + ((end.x - origin.x) * 0.48),
          y: origin.y + ((end.y - origin.y) * 0.48)
        )
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(
          path,
          with: .color(OutwitColors.tutorialBurst),
          style: StrokeStyle(lineWidth: size.width * 0.08, lineCap: .round)
        )
      }
    }
    .frame(width: 28, height: 28)
    .accessibilityHidden(true)
  }
}

struct TutorialCoinTrail: View {
  private let coins: [(x: CGFloat, y: CGFloat, size: CGFloat, angle: Double)] = [
    (45, 145, 30, -6),
    (75, 123, 34, -3),
    (94, 82, 40, 2),
    (111, 17, 52, 6),
  ]

  var body: some View {
    ZStack(alignment: .topLeading) {
      Canvas { context, _ in
        var trail = Path()
        trail.move(to: CGPoint(x: 31, y: 188))
        trail.addCurve(
          to: CGPoint(x: 137, y: 35),
          control1: CGPoint(x: 82, y: 171),
          control2: CGPoint(x: 135, y: 111)
        )
        context.stroke(
          trail,
          with: .color(Color(red: 1, green: 216 / 255, blue: 74 / 255).opacity(0.28)),
          style: StrokeStyle(lineWidth: 18, lineCap: .round)
        )
        context.stroke(
          trail,
          with: .color(.white.opacity(0.9)),
          style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
        )

        var arrow = Path()
        arrow.move(to: CGPoint(x: 139, y: 34))
        arrow.addLine(to: CGPoint(x: 119, y: 17))
        arrow.addLine(to: CGPoint(x: 126, y: 15))
        arrow.addLine(to: CGPoint(x: 116, y: 4))
        arrow.addLine(to: CGPoint(x: 139, y: 14))
        arrow.addLine(to: CGPoint(x: 133, y: 18))
        arrow.addLine(to: CGPoint(x: 146, y: 27))
        context.stroke(
          arrow,
          with: .color(Color(red: 1, green: 217 / 255, blue: 79 / 255)),
          style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
          arrow,
          with: .color(.white.opacity(0.92)),
          style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
      }
      .shadow(color: Color.yellow.opacity(0.32), radius: 10)

      ForEach(Array(coins.enumerated()), id: \.offset) { _, coin in
        TutorialCoin(size: coin.size, angle: coin.angle)
          .position(x: coin.x + (coin.size / 2), y: coin.y + (coin.size / 2))
      }
    }
    .frame(width: 160, height: 194)
    .accessibilityHidden(true)
  }
}
