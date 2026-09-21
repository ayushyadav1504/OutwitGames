import SwiftUI

struct FeedHeader: View {
  let coins: Int
  let playerInitials: String
  let onCoinsTap: () -> Void
  let onProfileTap: () -> Void

  var body: some View {
    HStack(spacing: OutwitSpacing.x4) {
      Image("OutwitMarkPrimary")
        .resizable()
        .scaledToFit()
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)

      Button(action: onCoinsTap) {
        HStack(spacing: OutwitSpacing.x1) {
          Image("TutorialCoin")
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
          Text(coins, format: .number)
            .font(OutwitTypography.label)
            .foregroundStyle(OutwitColors.ink)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("feed.redeem_coins")
      .accessibilityIdentifier("feed-coin-balance")

      Button(action: onProfileTap) {
        Text(verbatim: playerInitials)
          .font(OutwitTypography.label)
          .foregroundStyle(OutwitColors.ink)
          .frame(width: 44, height: 44)
          .background(.white.opacity(0.72), in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("feed.profile")
      .accessibilityIdentifier("feed-profile")
    }
    .padding(.leading, OutwitSpacing.x4)
    .padding(.trailing, OutwitSpacing.x2)
    .frame(height: 56)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
    .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
  }
}
