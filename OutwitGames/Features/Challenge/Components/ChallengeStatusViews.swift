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

struct ChallengeResultView: View {
  let outcome: ChallengeOutcome
  let multiplier: ChallengeMultiplierViewData?
  let actionState: ChallengeResultActionState
  let onRetry: () -> Void
  let onMultiply: () -> Void
  let onContinue: () -> Void
  let onWheelSettled: () -> Void

  var body: some View {
    ZStack {
      OutwitColors.softWhite.ignoresSafeArea()
      if let multiplier {
        ChallengeMultiplierView(
          data: multiplier,
          onContinue: onContinue,
          onSettled: onWheelSettled
        )
      } else {
        ChallengeResultSummary(
          outcome: outcome,
          actionState: actionState,
          onRetry: onRetry,
          onMultiply: onMultiply,
          onContinue: onContinue
        )
      }
    }
    .accessibilityIdentifier("challenge-result")
  }
}

private struct ChallengeResultSummary: View {
  let outcome: ChallengeOutcome
  let actionState: ChallengeResultActionState
  let onRetry: () -> Void
  let onMultiply: () -> Void
  let onContinue: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: OutwitSpacing.x6) {
        Spacer(minLength: OutwitSpacing.x6)
        Image(systemName: outcome.won ? "trophy.fill" : "flag.checkered")
          .font(.system(size: 58, weight: .bold))
          .foregroundStyle(outcome.won ? .yellow : OutwitColors.action)
          .symbolEffect(.bounce, value: outcome.won)

        Text(outcome.won ? "challenge.result.won" : "challenge.result.near_miss")
          .font(OutwitTypography.headlineLarge)
          .foregroundStyle(OutwitColors.ink)
          .multilineTextAlignment(.center)

        resultCard

        VStack(spacing: OutwitSpacing.x3) {
          if outcome.won {
            rewardedButton(
              title: "challenge.result.add_bonus",
              isBusy: actionState == .multiplying,
              action: onMultiply
            )
            Button("challenge.result.collect", action: onContinue)
              .font(OutwitTypography.label)
              .foregroundStyle(OutwitColors.action)
          } else {
            rewardedButton(
              title: "challenge.result.retry_ad",
              isBusy: actionState == .retrying,
              action: onRetry
            )
            Button("challenge.result.home", action: onContinue)
              .font(OutwitTypography.label)
              .foregroundStyle(OutwitColors.action)
          }
        }
        .frame(maxWidth: 340)
        Spacer(minLength: OutwitSpacing.x6)
      }
      .padding(OutwitSpacing.pageGutter)
      .frame(maxWidth: .infinity)
    }
  }

  private var resultCard: some View {
    VStack(spacing: OutwitSpacing.x3) {
      if let score = outcome.score {
        HStack(alignment: .firstTextBaseline, spacing: OutwitSpacing.x2) {
          Text("challenge.result.score")
            .font(OutwitTypography.body)
            .foregroundStyle(OutwitColors.mutedInk)
          Text(score.formatted())
            .font(OutwitTypography.headlineLarge)
            .foregroundStyle(OutwitColors.ink)
          if let target = outcome.target {
            Text("/ \(target.formatted())")
              .font(OutwitTypography.headlineSmall)
              .foregroundStyle(OutwitColors.mutedInk)
          }
        }
      }

      if outcome.won, outcome.totalCoins > 0 {
        HStack(spacing: OutwitSpacing.x2) {
          Image("TutorialCoin")
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: 36)
          Text(outcome.totalCoins, format: .number)
            .font(OutwitTypography.headlineLarge)
            .foregroundStyle(OutwitColors.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("challenge.result.coins")
      }
    }
    .padding(OutwitSpacing.x6)
    .frame(maxWidth: 340)
    .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(OutwitColors.paleBorder, lineWidth: 1)
    )
  }

  private func rewardedButton(
    title: LocalizedStringKey,
    isBusy: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: OutwitSpacing.x2) {
        if isBusy {
          ProgressView().tint(.white)
        } else {
          Image(systemName: "play.rectangle.fill")
        }
        Text(title)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.outwitPrimary)
    .disabled(actionState != .idle)
  }
}
