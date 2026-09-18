import SwiftUI

struct TutorialChallengesView: View {
  let onBeat: () -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      TutorialHeader()
        .offset(x: 16, y: 10)

      TutorialAccentBurst()
        .offset(x: 10, y: 58)

      VStack(alignment: .leading, spacing: 0) {
        Text("onboarding.challenges.title")
          .foregroundStyle(OutwitColors.ink)
        Text("onboarding.challenges.accent")
          .foregroundStyle(OutwitColors.red)
        Text("onboarding.challenges.body")
          .font(.custom("NunitoSans-SemiBold", fixedSize: 14))
          .foregroundStyle(OutwitColors.graphite)
          .frame(width: 174, alignment: .leading)
          .padding(.top, 8)
      }
      .font(.custom("NunitoSans-Black", fixedSize: 29))
      .tracking(-0.7)
      .offset(x: 24, y: 78)

      TutorialCoinTrail()
        .offset(x: 142, y: 40)

      challengeCard
        .frame(width: 304, height: 310)
        .offset(x: 28, y: 226)

      TutorialCoin(size: 27, angle: -9)
        .offset(x: 162, y: 207)
    }
    .frame(width: 360, height: 640, alignment: .topLeading)
  }

  private var challengeCard: some View {
    TutorialCardSurface(angle: .degrees(0.2), cornerRadius: 22, recedes: true) {
      VStack(spacing: 0) {
        ZStack(alignment: .topLeading) {
          Image("TutorialFruit")
            .resizable()
            .scaledToFill()
            .frame(width: 290, height: 151)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

          Image("TutorialFruit")
            .resizable()
            .scaledToFill()
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(3)
            .background(
              .white,
              in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .shadow(color: OutwitColors.ink.opacity(0.16), radius: 7, y: 3)
            .offset(x: 10, y: 110)
        }
        .frame(width: 290, height: 158)

        Text("onboarding.challenge.card.title")
          .font(.custom("NunitoSans-Black", fixedSize: 25))
          .foregroundStyle(OutwitColors.ink)
          .padding(.top, 2)

        HStack(alignment: .lastTextBaseline, spacing: 7) {
          Text("onboarding.challenge.card.beat")
            .font(.custom("NunitoSans-Bold", fixedSize: 14))
            .foregroundStyle(OutwitColors.graphite)
          Text("onboarding.challenge.card.score")
            .font(.custom("NunitoSans-Black", fixedSize: 29))
            .foregroundStyle(OutwitColors.red)
        }

        Spacer(minLength: 4)

        TutorialActionButton(
          title: "onboarding.challenge.card.action",
          height: 34,
          fontSize: 12,
          cornerRadius: 11,
          action: onBeat
        )
        .padding(.horizontal, 15)
        .padding(.bottom, 12)
      }
      .padding(.horizontal, 7)
      .padding(.top, 7)
    }
  }
}
