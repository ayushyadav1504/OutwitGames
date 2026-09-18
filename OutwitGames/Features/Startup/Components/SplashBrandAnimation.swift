import SwiftUI

struct SplashBrandAnimation: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress: CGFloat = 0

  var body: some View {
    SplashBrandFrame(progress: reduceMotion ? 1 : progress)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("startup-brand")
      .onAppear {
        guard !reduceMotion, progress == 0 else {
          progress = 1
          return
        }
        withAnimation(.linear(duration: SplashBrandMotion.duration)) {
          progress = 1
        }
      }
  }
}

private struct SplashBrandFrame: View, Animatable {
  var progress: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  var body: some View {
    let motion = SplashBrandMotion(progress: progress)

    VStack(spacing: 0) {
      ZStack(alignment: .topLeading) {
        Image("OutwitMarkWhite")
          .resizable()
          .scaledToFit()
          .frame(width: 168, height: 168)
          .position(x: 92, y: 92)
          .opacity(motion.markOpacity)
          .scaleEffect(motion.markScale)

        Circle()
          .fill(OutwitColors.red)
          .frame(width: 62, height: 62)
          .offset(x: 28, y: 42)
          .opacity(motion.eyeCoverOpacity)

        Text(verbatim: "O")
          .font(.custom("NunitoSans-ExtraBold", fixedSize: 144))
          .tracking(-8.64)
          .foregroundStyle(.white)
          .frame(width: 184, height: 184)
          .scaleEffect(
            x: motion.initialScale,
            y: motion.initialScale * motion.winkScale
          )
          .offset(x: motion.initialOffsetX, y: motion.initialOffsetY)
          .opacity(motion.initialOpacity)
      }
      .frame(width: 184, height: 184)

      VStack(spacing: 8) {
        Text("startup.brand_name")
          .font(.custom("NunitoSans-ExtraBold", fixedSize: 44))
          .tracking(-1.1)

        Text("startup.tagline")
          .font(.custom("NunitoSans-Bold", fixedSize: 16))
          .tracking(0.64)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .foregroundStyle(.white)
      .frame(width: 184)
      .padding(.top, 12)
      .offset(y: motion.copyOffsetY)
      .opacity(motion.copyOpacity)
    }
    .frame(width: 184, height: 276, alignment: .top)
  }
}

#Preview {
  ZStack {
    OutwitColors.red.ignoresSafeArea()
    SplashBrandAnimation()
  }
}
