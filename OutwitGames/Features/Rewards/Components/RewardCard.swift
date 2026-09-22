import SwiftUI

struct RewardCard: View {
  @Environment(\.locale) private var locale

  let reward: RewardItem
  let balance: Int
  let cashOut: CashOutEligibility
  let isRegistered: Bool
  let redeemingSKU: String?
  let onRedeem: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: OutwitSpacing.x2) {
      merchantPlate

      Text(verbatim: reward.name)
        .font(OutwitTypography.bodySmall.weight(.semibold))
        .foregroundStyle(OutwitColors.ink)
        .lineLimit(1)

      HStack(spacing: OutwitSpacing.x1) {
        Image("OutwitCoin3D")
          .resizable()
          .scaledToFit()
          .frame(width: 23, height: 23)
        Text(reward.coinCost, format: .number)
          .font(OutwitTypography.bodySmall.weight(.bold))
        Text("rewards.coins")
          .font(OutwitTypography.bodySmall)
      }
      .foregroundStyle(OutwitColors.ink)

      Button(action: onRedeem) {
        Group {
          if isRedeeming {
            ProgressView().tint(.white)
          } else {
            Text(actionKey)
              .lineLimit(1)
              .minimumScaleFactor(0.72)
          }
        }
        .font(OutwitTypography.bodySmall.weight(.bold))
        .frame(maxWidth: .infinity, minHeight: 38)
      }
      .buttonStyle(.borderedProminent)
      .tint(OutwitColors.action)
      .disabled(!canRedeem)
      .accessibilityIdentifier("reward-redeem-\(reward.sku)")
    }
    .padding(OutwitSpacing.x3)
    .frame(maxWidth: .infinity, minHeight: 225, alignment: .top)
    .background(.white, in: RoundedRectangle(cornerRadius: OutwitRadius.card))
    .overlay(
      RoundedRectangle(cornerRadius: OutwitRadius.card)
        .stroke(OutwitColors.paleBorder, lineWidth: 1)
    )
    .shadow(color: OutwitColors.ink.opacity(0.08), radius: 9, y: 5)
  }

  private var merchantPlate: some View {
    let value = RewardFormatting.value(
      cents: reward.fiatValueCents,
      currency: reward.currency,
      locale: locale
    )
    let merchant = RewardFormatting.merchant(from: reward.name, value: value)
    return VStack(alignment: .leading, spacing: 2) {
      Text(verbatim: merchant.isEmpty ? reward.name : merchant)
        .font(.custom("NunitoSans-ExtraBold", size: 10, relativeTo: .caption))
        .lineLimit(1)
      Text(verbatim: value)
        .font(.custom("NunitoSans-ExtraBold", size: 25, relativeTo: .title2))
        .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.42))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .foregroundStyle(.white)
    .padding(OutwitSpacing.x3)
    .frame(maxWidth: .infinity, minHeight: 78)
    .background(OutwitColors.ink, in: RoundedRectangle(cornerRadius: 12))
    .saturation(cashOut.unlocked && isRegistered ? 1 : 0)
    .opacity(cashOut.unlocked && isRegistered ? 1 : 0.68)
  }

  private var isRedeeming: Bool { redeemingSKU == reward.sku }

  private var canRedeem: Bool {
    isRegistered
      && cashOut.rewardsEnabled
      && cashOut.unlocked
      && cashOut.eligible
      && reward.isInStock
      && reward.coinsNeeded(balance: balance) == 0
      && redeemingSKU == nil
  }

  private var actionKey: LocalizedStringKey {
    if isRedeeming { return "rewards.action.redeeming" }
    if !isRegistered { return "rewards.action.login" }
    if !cashOut.rewardsEnabled { return "rewards.action.unavailable" }
    if !cashOut.unlocked { return "rewards.action.locked" }
    if !cashOut.eligible { return "rewards.action.not_eligible" }
    if !reward.isInStock { return "rewards.action.out_of_stock" }
    if reward.coinsNeeded(balance: balance) > 0 { return "rewards.action.more_coins" }
    return "rewards.action.redeem"
  }
}
