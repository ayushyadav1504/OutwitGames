import SwiftUI

struct NotificationSoftAskView: View {
  let isBusy: Bool
  let onTurnOn: () -> Void
  let onSkip: () -> Void

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: OutwitSpacing.x8) {
          Spacer(minLength: OutwitSpacing.x8)

          VStack(spacing: OutwitSpacing.x8) {
            notificationArt

            VStack(spacing: OutwitSpacing.x3) {
              Text("notifications.title")
                .font(OutwitTypography.headlineLarge)
                .foregroundStyle(OutwitColors.ink)
              Text("notifications.body")
                .font(OutwitTypography.body)
                .foregroundStyle(OutwitColors.mutedInk)
            }
            .multilineTextAlignment(.center)
          }

          Spacer(minLength: OutwitSpacing.x8)

          VStack(spacing: OutwitSpacing.x3) {
            Button(action: onTurnOn) {
              if isBusy {
                ProgressView()
                  .tint(.white)
                  .accessibilityLabel("common.loading")
              } else {
                Text("notifications.action.turn_on")
              }
            }
            .buttonStyle(.outwitPrimary)
            .accessibilityIdentifier("notifications-turn-on")

            Button("notifications.action.not_now", action: onSkip)
              .font(OutwitTypography.label)
              .foregroundStyle(OutwitColors.ink)
              .frame(maxWidth: .infinity, minHeight: 48)
              .background(
                RoundedRectangle(cornerRadius: OutwitRadius.button, style: .continuous)
                  .stroke(OutwitColors.paleBorder, lineWidth: 1.5)
              )
              .accessibilityIdentifier("notifications-not-now")
          }
          .disabled(isBusy)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, OutwitSpacing.pageGutter)
        .padding(.bottom, OutwitSpacing.x6)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .background(OutwitColors.softWhite.ignoresSafeArea())
  }

  private var notificationArt: some View {
    ZStack(alignment: .topTrailing) {
      Circle()
        .fill(OutwitColors.redTint)
        .frame(width: 164, height: 164)

      Image("OutwitMarkPrimary")
        .resizable()
        .scaledToFit()
        .frame(width: 92, height: 92)
        .position(x: 82, y: 82)

      Image(systemName: "bell.fill")
        .font(.system(size: 25, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 54, height: 54)
        .background(OutwitColors.action, in: Circle())
        .overlay(Circle().stroke(OutwitColors.softWhite, lineWidth: 5))
        .accessibilityHidden(true)
    }
    .frame(width: 164, height: 164)
    .accessibilityHidden(true)
  }
}
