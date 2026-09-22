import SwiftUI

struct ChallengePreparingView: View {
  let title: String
  let onCancel: () -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VStack(spacing: OutwitSpacing.x4) {
        ProgressView()
          .tint(OutwitColors.action)
          .controlSize(.large)
        Text("challenge.preparing")
          .font(OutwitTypography.headlineSmall)
          .foregroundStyle(OutwitColors.ink)
        if !title.isEmpty {
          Text(verbatim: title)
            .font(OutwitTypography.body)
            .foregroundStyle(OutwitColors.mutedInk)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Button(action: onCancel) {
        Image(systemName: "xmark")
          .font(.system(size: 17, weight: .bold))
          .frame(width: 44, height: 44)
          .background(.white, in: Circle())
          .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
      }
      .foregroundStyle(OutwitColors.ink)
      .accessibilityLabel("challenge.close")
      .padding(OutwitSpacing.x4)
    }
    .background(OutwitColors.softWhite.ignoresSafeArea())
    .accessibilityIdentifier("challenge-preparing")
  }
}

struct ChallengeErrorView: View {
  let messageKey: String
  let onRetry: () -> Void
  let onClose: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("challenge.error.title", systemImage: "exclamationmark.triangle")
        .font(OutwitTypography.headlineSmall)
    } description: {
      Text(LocalizedStringKey(messageKey))
        .font(OutwitTypography.body)
    } actions: {
      VStack(spacing: OutwitSpacing.x3) {
        Button("common.retry", action: onRetry)
          .buttonStyle(.outwitPrimary)
        Button("challenge.close", role: .cancel, action: onClose)
          .font(OutwitTypography.label)
          .foregroundStyle(OutwitColors.action)
      }
      .frame(maxWidth: 320)
    }
    .padding(OutwitSpacing.pageGutter)
    .background(OutwitColors.softWhite.ignoresSafeArea())
    .accessibilityIdentifier("challenge-error")
  }
}
