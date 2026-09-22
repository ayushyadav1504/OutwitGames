import SwiftUI

struct RewardOutcomeView: View {
  @Environment(\.locale) private var locale

  let redemption: RewardRedemption
  let onDone: () -> Void
  let onCopy: () -> Void
  let onAppear: () -> Void

  @State private var copied = false

  var body: some View {
    ScrollView {
      VStack(spacing: OutwitSpacing.x4) {
        Image(systemName: isReady ? "checkmark.circle.fill" : "clock.badge.fill")
          .font(.system(size: 68, weight: .semibold))
          .foregroundStyle(isReady ? Color.green : Color.orange)
          .accessibilityHidden(true)

        Text(outcomeTitleKey)
          .font(OutwitTypography.headlineLarge)
          .multilineTextAlignment(.center)

        Text(outcomeMessageKey)
          .font(OutwitTypography.bodySmall)
          .foregroundStyle(OutwitColors.mutedInk)
          .multilineTextAlignment(.center)

        outcomeCard

        Button("common.done", action: onDone)
          .buttonStyle(.outwitPrimary)
      }
      .padding(OutwitSpacing.pageGutter)
      .padding(.top, OutwitSpacing.x8)
    }
    .background(OutwitColors.softWhite)
    .onAppear(perform: onAppear)
  }

  private var outcomeCard: some View {
    VStack(alignment: .leading, spacing: OutwitSpacing.x3) {
      HStack {
        VStack(alignment: .leading, spacing: OutwitSpacing.x1) {
          Text(verbatim: merchant)
            .font(OutwitTypography.bodySmall.weight(.bold))
          Text(verbatim: value)
            .font(.custom("NunitoSans-ExtraBold", size: 30, relativeTo: .title))
            .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.42))
        }
        Spacer()
        Image(systemName: "giftcard.fill")
          .font(.title)
          .foregroundStyle(.white.opacity(0.8))
      }
      .foregroundStyle(.white)
      .padding(OutwitSpacing.x4)
      .background(OutwitColors.ink, in: RoundedRectangle(cornerRadius: 16))

      Text(outcomeLabelKey)
        .font(.caption.weight(.bold))
        .foregroundStyle(OutwitColors.mutedInk)

      Text(verbatim: isReady ? redemption.code ?? "" : status)
        .font(.system(.title3, design: .monospaced, weight: .bold))
        .foregroundStyle(OutwitColors.ink)
        .textSelection(.enabled)

      Button {
        onCopy()
        copied = true
        Task {
          try? await Task.sleep(for: .seconds(1.8))
          copied = false
        }
      } label: {
        Label {
          Text(copyActionKey)
        } icon: {
          Image(systemName: copied ? "checkmark" : "doc.on.doc")
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(OutwitColors.action)
      .disabled(!isReady)

      Text(outcomeNoteKey)
        .font(.caption)
        .foregroundStyle(OutwitColors.mutedInk)
    }
    .padding(OutwitSpacing.x4)
    .background(.white, in: RoundedRectangle(cornerRadius: OutwitRadius.card))
    .overlay(RoundedRectangle(cornerRadius: OutwitRadius.card).stroke(OutwitColors.paleBorder))
  }

  private var isReady: Bool {
    redemption.status == .fulfilled && redemption.code?.isEmpty == false
  }

  private var outcomeTitleKey: LocalizedStringKey {
    isReady ? "rewards.outcome.ready.title" : "rewards.outcome.pending.title"
  }

  private var outcomeMessageKey: LocalizedStringKey {
    isReady ? "rewards.outcome.ready.message" : "rewards.outcome.pending.message"
  }

  private var outcomeLabelKey: LocalizedStringKey {
    isReady ? "rewards.outcome.code" : "rewards.outcome.status"
  }

  private var copyActionKey: LocalizedStringKey {
    copied ? "rewards.outcome.copied" : "rewards.outcome.copy"
  }

  private var outcomeNoteKey: LocalizedStringKey {
    isReady ? "rewards.outcome.ready.note" : "rewards.outcome.pending.note"
  }

  private var value: String {
    RewardFormatting.value(
      cents: redemption.fiatValueCents,
      currency: redemption.currency,
      locale: locale
    )
  }

  private var merchant: String {
    RewardFormatting.merchant(from: redemption.rewardName ?? "", value: value)
  }

  private var status: String {
    String(localized: String.LocalizationValue("rewards.status.\(redemption.status.rawValue)"))
  }
}
