import SwiftUI

struct TutorialRewardsView: View {
  var body: some View {
    ZStack(alignment: .topLeading) {
      TutorialHeader()
        .offset(x: 16, y: 10)

      TutorialAccentBurst()
        .offset(x: 19, y: 74)

      TutorialAccentBurst()
        .scaleEffect(0.72)
        .rotationEffect(.degrees(180))
        .offset(x: 302, y: 126)

      VStack(spacing: 0) {
        Text("onboarding.rewards.title")
          .foregroundStyle(OutwitColors.ink)
        Text("onboarding.rewards.accent")
          .foregroundStyle(OutwitColors.red)
        Text("onboarding.rewards.body")
          .font(.custom("NunitoSans-SemiBold", fixedSize: 15))
          .foregroundStyle(OutwitColors.graphite)
          .padding(.top, 8)
      }
      .font(.custom("NunitoSans-Black", fixedSize: 34))
      .tracking(-0.8)
      .frame(width: 320)
      .offset(x: 20, y: 78)

      Image("TutorialWallet")
        .resizable()
        .scaledToFit()
        .frame(width: 284, height: 275)
        .offset(x: 38, y: 182)
        .accessibilityHidden(true)

      HStack(spacing: 7) {
        cashCard(
          amount: "onboarding.rewards.amount.small",
          coins: "onboarding.rewards.coins.small",
          angle: -0.7
        )
        cashCard(
          amount: "onboarding.rewards.amount.medium",
          coins: "onboarding.rewards.coins.medium",
          angle: 0.45
        )
        cashCard(
          amount: "onboarding.rewards.amount.large",
          coins: "onboarding.rewards.coins.large",
          angle: -0.35
        )
      }
      .frame(width: 328, height: 88)
      .offset(x: 16, y: 458)
    }
    .frame(width: 360, height: 640, alignment: .topLeading)
  }

  private func cashCard(
    amount: LocalizedStringKey,
    coins: LocalizedStringKey,
    angle: Double
  ) -> some View {
    TutorialCardSurface(angle: .degrees(angle), cornerRadius: 14) {
      VStack(spacing: 10) {
        Text(amount)
          .font(.custom("NunitoSans-Black", fixedSize: 25))
          .foregroundStyle(OutwitColors.red)
          .lineLimit(1)
          .minimumScaleFactor(0.72)

        HStack(spacing: 4) {
          TutorialCoin(size: 17, angle: -5)
          Text(coins)
            .font(.custom("NunitoSans-ExtraBold", fixedSize: 11))
            .foregroundStyle(OutwitColors.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.66)
        }
      }
      .padding(.horizontal, 5)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
