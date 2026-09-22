import SwiftUI

struct ReferralGateView: View {
  let progress: ReferralProgress
  let referral: ReferralInfo?
  let isLoading: Bool
  let errorKey: String?
  let onReload: () -> Void

  var body: some View {
    VStack(spacing: OutwitSpacing.x3) {
      Image(systemName: "person.2.badge.plus")
        .font(.system(size: 54, weight: .medium))
        .foregroundStyle(OutwitColors.action)
        .accessibilityHidden(true)

      Text("rewards.cashout.unlock")
        .font(OutwitTypography.headlineLarge)
        .foregroundStyle(OutwitColors.ink)

      HStack(spacing: 3) {
        Text("rewards.referral.invite_prefix")
        Text(progress.needed, format: .number).bold()
        Text("rewards.referral.invite_suffix")
      }
      .font(OutwitTypography.bodySmall)
      .foregroundStyle(OutwitColors.mutedInk)
      .multilineTextAlignment(.center)

      ProgressView(
        value: Double(progress.qualified),
        total: Double(max(progress.threshold, 1))
      )
      .tint(OutwitColors.action)

      Text("\(progress.qualified)/\(progress.threshold)")
        .font(OutwitTypography.label)
        .foregroundStyle(OutwitColors.action)

      if let errorKey {
        Text(LocalizedStringKey(errorKey))
          .font(OutwitTypography.bodySmall)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
      }

      inviteAction
    }
    .padding(OutwitSpacing.x6)
    .frame(maxWidth: .infinity)
    .background(
      LinearGradient(
        colors: [.white, OutwitColors.redTint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 26)
    )
    .overlay(RoundedRectangle(cornerRadius: 26).stroke(OutwitColors.paleBorder))
    .shadow(color: OutwitColors.ink.opacity(0.1), radius: 16, y: 8)
  }

  @ViewBuilder
  private var inviteAction: some View {
    if let url = referral?.shareURL, referral?.canShare == true {
      ShareLink(
        item: url,
        subject: Text("rewards.share.subject"),
        message: Text("rewards.share.message")
      ) {
        Label("rewards.invite_friends", systemImage: "square.and.arrow.up")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.outwitPrimary)
    } else {
      Button(action: onReload) {
        if isLoading {
          ProgressView().tint(.white)
        } else {
          Text("rewards.invite_friends")
        }
      }
      .buttonStyle(.outwitPrimary)
      .disabled(isLoading)
    }
  }
}
