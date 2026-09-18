import SwiftUI

struct TutorialCardSurface<Content: View>: View {
  let angle: Angle
  let cornerRadius: CGFloat
  let recedes: Bool
  @ViewBuilder let content: () -> Content

  init(
    angle: Angle = .zero,
    cornerRadius: CGFloat = 20,
    recedes: Bool = false,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.angle = angle
    self.cornerRadius = cornerRadius
    self.recedes = recedes
    self.content = content
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    content()
      .background(.white, in: shape)
      .overlay(shape.stroke(OutwitColors.paleBorder.opacity(0.78), lineWidth: 1.1))
      .clipShape(shape)
      .shadow(color: OutwitColors.ink.opacity(0.12), radius: 17, y: 7)
      .shadow(color: OutwitColors.ink.opacity(0.055), radius: 3, y: 10)
      .rotationEffect(angle)
      .rotation3DEffect(
        recedes ? .degrees(2.4) : .zero,
        axis: (x: 1, y: 0, z: 0),
        anchor: .bottom,
        perspective: 0.22
      )
  }
}
