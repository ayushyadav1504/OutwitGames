import SwiftUI

struct RedemptionHistoryView: View {
  @Environment(\.locale) private var locale

  let redemptions: [RewardRedemption]
  let isLoading: Bool
  let errorKey: String?
  let onBrowse: () -> Void
  let onOpen: (RewardRedemption) -> Void

  var body: some View {
    VStack(spacing: OutwitSpacing.x4) {
      summary

      Text("rewards.history.previous")
        .font(OutwitTypography.headlineSmall)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let errorKey {
        Text(LocalizedStringKey(errorKey))
          .font(OutwitTypography.bodySmall)
          .foregroundStyle(.red)
      } else if redemptions.isEmpty, isLoading {
        ProgressView().padding(OutwitSpacing.x8)
      } else if redemptions.isEmpty {
        emptyState
      } else {
        ForEach(redemptions) { redemption in
          historyRow(redemption)
        }
      }
    }
  }

  private var summary: some View {
    let settled = redemptions.filter { !$0.status.returnsCoins }
    let total = settled.reduce(0) { $0 + $1.fiatValueCents }
    let currency = settled.first?.currency ?? "INR"
    return VStack(alignment: .leading, spacing: OutwitSpacing.x1) {
      Text("rewards.history.total")
        .font(OutwitTypography.bodySmall.weight(.bold))
        .foregroundStyle(Color.green)
      Text(
        verbatim: RewardFormatting.value(cents: total, currency: currency, locale: locale)
      )
      .font(.custom("NunitoSans-Bold", size: 38, relativeTo: .largeTitle))
      .foregroundStyle(OutwitColors.ink)
      HStack(spacing: 4) {
        Text(settled.count, format: .number)
        Text("rewards.history.cards")
      }
      .font(OutwitTypography.bodySmall)
      .foregroundStyle(OutwitColors.mutedInk)
    }
    .padding(OutwitSpacing.x4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: OutwitRadius.card))
  }

  private var emptyState: some View {
    VStack(spacing: OutwitSpacing.x3) {
      Text("rewards.history.empty.title")
        .font(OutwitTypography.headlineSmall)
      Text("rewards.history.empty.message")
        .font(OutwitTypography.bodySmall)
        .foregroundStyle(OutwitColors.mutedInk)
        .multilineTextAlignment(.center)
      Button("rewards.history.browse", action: onBrowse)
        .buttonStyle(.bordered)
        .tint(OutwitColors.action)
    }
    .padding(OutwitSpacing.x6)
    .frame(maxWidth: .infinity)
    .background(.white, in: RoundedRectangle(cornerRadius: OutwitRadius.card))
    .overlay(RoundedRectangle(cornerRadius: OutwitRadius.card).stroke(OutwitColors.paleBorder))
  }

  private func historyRow(_ redemption: RewardRedemption) -> some View {
    Button {
      onOpen(redemption)
    } label: {
      HStack(spacing: OutwitSpacing.x3) {
        VStack(alignment: .leading, spacing: OutwitSpacing.x1) {
          Text(verbatim: redemption.rewardName ?? String(localized: "rewards.reward"))
            .font(OutwitTypography.bodySmall.weight(.bold))
            .foregroundStyle(OutwitColors.ink)
            .lineLimit(1)
          HStack(spacing: 4) {
            if let date = redemption.requestedAt {
              Text(date, format: .dateTime.day().month(.abbreviated))
              Text(verbatim: "·")
            }
            Text(redemption.coinCost, format: .number)
            Text("rewards.coins")
          }
          .font(.caption)
          .foregroundStyle(OutwitColors.mutedInk)
          Text(verbatim: codeLine(redemption))
            .font(.caption.weight(.bold))
            .foregroundStyle(OutwitColors.action)
        }
        Spacer()
        Text(
          verbatim: RewardFormatting.value(
            cents: redemption.fiatValueCents,
            currency: redemption.currency,
            locale: locale
          )
        )
        .font(OutwitTypography.headlineSmall)
        .foregroundStyle(OutwitColors.action)
      }
      .padding(OutwitSpacing.x4)
      .frame(maxWidth: .infinity)
      .background(.white, in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(OutwitColors.paleBorder))
    }
    .buttonStyle(.plain)
    .disabled(!redemption.hasOutcome)
  }

  private func codeLine(_ redemption: RewardRedemption) -> String {
    if redemption.status == .fulfilled, let code = redemption.code, !code.isEmpty {
      return RewardFormatting.maskedCode(code)
    }
    return String(localized: String.LocalizationValue(statusKey(redemption.status)))
  }

  private func statusKey(_ status: RewardRedemptionStatus) -> String {
    "rewards.status.\(status.rawValue)"
  }
}
