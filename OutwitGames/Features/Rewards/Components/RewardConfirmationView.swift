import SwiftUI

struct RewardConfirmationView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale

  let reward: RewardItem
  let balanceAfter: Int
  let onConfirm: () -> Void

  var body: some View {
    VStack(spacing: OutwitSpacing.x3) {
      Capsule()
        .fill(OutwitColors.paleBorder)
        .frame(width: 40, height: 4)

      Image("OutwitCoin3D")
        .resizable()
        .scaledToFit()
        .frame(width: 82, height: 82)
        .accessibilityHidden(true)

      Text("rewards.confirm.eyebrow")
        .font(.caption.weight(.heavy))
        .foregroundStyle(OutwitColors.action)

      Text("rewards.confirm.title")
        .font(OutwitTypography.headlineLarge)
        .multilineTextAlignment(.center)

      Text(verbatim: rewardLabel)
        .font(OutwitTypography.bodyEmphasized)
        .foregroundStyle(OutwitColors.ink)
        .multilineTextAlignment(.center)

      HStack(spacing: 4) {
        Text("rewards.confirm.cost_prefix")
        Text(reward.coinCost, format: .number).bold()
        Text("rewards.coins")
      }
      .font(OutwitTypography.bodySmall)
      .foregroundStyle(OutwitColors.mutedInk)

      HStack {
        Text("rewards.confirm.balance_after")
          .font(OutwitTypography.bodySmall)
          .foregroundStyle(OutwitColors.mutedInk)
        Spacer()
        Text(balanceAfter, format: .number)
          .font(OutwitTypography.label)
        Text("rewards.coins")
          .font(OutwitTypography.bodySmall)
      }
      .padding(OutwitSpacing.x4)
      .background(OutwitColors.softWhite, in: RoundedRectangle(cornerRadius: 16))

      Button {
        onConfirm()
        dismiss()
      } label: {
        Text("rewards.confirm.action")
      }
      .buttonStyle(.outwitPrimary)

      Button("rewards.confirm.not_now") { dismiss() }
        .font(OutwitTypography.label)
        .foregroundStyle(OutwitColors.action)
    }
    .padding(.horizontal, OutwitSpacing.pageGutter)
    .padding(.top, OutwitSpacing.x3)
    .padding(.bottom, OutwitSpacing.x6)
    .presentationDetents([.height(500)])
    .presentationDragIndicator(.hidden)
    .presentationBackground(.white)
  }

  private var rewardLabel: String {
    let value = RewardFormatting.value(
      cents: reward.fiatValueCents,
      currency: reward.currency,
      locale: locale
    )
    let merchant = RewardFormatting.merchant(from: reward.name, value: value)
    return [merchant, value].filter { !$0.isEmpty }.joined(separator: " ")
  }
}
