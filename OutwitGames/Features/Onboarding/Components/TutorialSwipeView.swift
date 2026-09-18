import SwiftUI

struct TutorialSwipeView: View {
  let onComplete: () -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      TutorialHeader()
        .offset(x: 16, y: 10)

      TutorialAccentBurst()
        .offset(x: 10, y: 57)

      VStack(alignment: .leading, spacing: 0) {
        Text("onboarding.swipe.title")
          .foregroundStyle(OutwitColors.ink)
        HStack(spacing: 6) {
          Text("onboarding.swipe.prefix")
            .foregroundStyle(OutwitColors.ink)
          Text("onboarding.swipe.accent")
            .foregroundStyle(OutwitColors.red)
        }
        Text("onboarding.swipe.body")
          .font(.custom("NunitoSans-SemiBold", fixedSize: 14))
          .foregroundStyle(OutwitColors.graphite)
          .padding(.top, 8)
      }
      .font(.custom("NunitoSans-Black", fixedSize: 29))
      .tracking(-0.6)
      .offset(x: 24, y: 76)

      Image("TutorialSwipeArrow")
        .resizable()
        .scaledToFit()
        .frame(width: 88, height: 150)
        .offset(x: 260, y: 62)
        .accessibilityHidden(true)

      fruitCard
        .frame(width: 320, height: 168)
        .offset(x: 20, y: 202)

      trafficCard
        .frame(width: 312, height: 164)
        .offset(x: 28, y: 381)
    }
    .frame(width: 360, height: 640, alignment: .topLeading)
  }

  private var fruitCard: some View {
    TutorialCardSurface(angle: .degrees(-0.7), cornerRadius: 19, recedes: true) {
      VStack(spacing: 0) {
        HStack(alignment: .top, spacing: 10) {
          Image("TutorialFruit")
            .resizable()
            .scaledToFill()
            .frame(width: 145, height: 115)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

          VStack(alignment: .leading, spacing: 2) {
            gameTitle("onboarding.swipe.card.fruit")
            Text("onboarding.swipe.card.your_score")
              .font(.custom("NunitoSans-Bold", fixedSize: 10))
              .foregroundStyle(OutwitColors.mutedInk)
              .padding(.top, 4)
            Text("onboarding.swipe.card.score")
              .font(.custom("NunitoSans-Black", fixedSize: 22))
              .foregroundStyle(OutwitColors.red)
              .lineLimit(1)
              .minimumScaleFactor(0.72)
            Text("onboarding.swipe.card.close")
              .font(.custom("NunitoSans-ExtraBold", fixedSize: 10))
              .foregroundStyle(OutwitColors.action)
              .padding(.horizontal, 7)
              .padding(.vertical, 4)
              .background(
                Color(red: 1, green: 236 / 255, blue: 235 / 255),
                in: Capsule()
              )
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)

        Spacer(minLength: 2)

        TutorialActionButton(
          title: "onboarding.swipe.card.retry",
          height: 31,
          fontSize: 12,
          cornerRadius: 15,
          action: onComplete
        )
        .padding(.leading, 58)
        .padding(.trailing, 8)
        .padding(.bottom, 8)
      }
    }
  }

  private var trafficCard: some View {
    TutorialCardSurface(angle: .degrees(-0.5), cornerRadius: 19, recedes: true) {
      HStack(spacing: 10) {
        Image("TutorialTraffic")
          .resizable()
          .scaledToFill()
          .frame(width: 140, height: 146)
          .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

        VStack(alignment: .leading, spacing: 0) {
          gameTitle("onboarding.swipe.card.traffic")

          HStack(alignment: .lastTextBaseline, spacing: 7) {
            Text("onboarding.swipe.card.beat")
              .font(.custom("NunitoSans-Bold", fixedSize: 11))
              .foregroundStyle(OutwitColors.graphite)
            Text("onboarding.swipe.card.target")
              .font(.custom("NunitoSans-Black", fixedSize: 25))
              .foregroundStyle(OutwitColors.red)
          }
          .padding(.top, 8)

          Spacer()

          TutorialActionButton(
            title: "onboarding.swipe.card.play",
            height: 32,
            fontSize: 11,
            cornerRadius: 10,
            action: onComplete
          )
        }
        .padding(.vertical, 3)
      }
      .padding(9)
    }
  }

  private func gameTitle(_ key: LocalizedStringKey) -> some View {
    Text(key)
      .font(.custom("NunitoSans-Black", fixedSize: 19))
      .foregroundStyle(OutwitColors.ink)
      .lineLimit(1)
      .minimumScaleFactor(0.72)
  }
}
