import SwiftUI

struct ChallengeCard: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.locale) private var locale

  let challenge: FeedChallenge
  let isActive: Bool
  let shouldPlaySwipeHint: Bool
  let onSwipeHintPlayed: () -> Void
  let onStart: () -> Void

  @State private var contentIsVisible = false
  @State private var swipeOffset: CGFloat = 0

  var body: some View {
    ZStack(alignment: .bottom) {
      FeedMediaBackground(challenge: challenge, isActive: isActive)

      VStack(spacing: OutwitSpacing.x2) {
        interactionSheet

        Image(systemName: "chevron.up")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.white.opacity(0.88))
          .accessibilityLabel("feed.swipe_up")
      }
      .padding(.horizontal, OutwitSpacing.x3)
      .padding(.bottom, OutwitSpacing.x3)
    }
    .offset(y: swipeOffset)
    .task(id: isActive) {
      await updateActiveState()
    }
    .accessibilityIdentifier("feed-card-\(challenge.id)")
  }

  private var interactionSheet: some View {
    VStack(spacing: OutwitSpacing.x3) {
      if !challenge.title.isEmpty {
        Text(verbatim: challenge.title)
          .font(OutwitTypography.bodyEmphasized)
          .foregroundStyle(OutwitColors.mutedInk)
          .lineLimit(1)
      }

      objectiveText
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)

      Text("feed.unlock_reward")
        .font(OutwitTypography.bodySmall)
        .foregroundStyle(OutwitColors.mutedInk)

      Button(action: onStart) {
        Text("feed.start_challenge")
      }
      .buttonStyle(.outwitPrimary)
      .accessibilityIdentifier("feed-start-challenge")
    }
    .padding(.horizontal, OutwitSpacing.x4)
    .padding(.top, OutwitSpacing.x6)
    .padding(.bottom, OutwitSpacing.x4)
    .background(.white, in: RoundedRectangle(cornerRadius: OutwitRadius.card, style: .continuous))
    .opacity(contentIsVisible ? 1 : 0)
    .scaleEffect(contentIsVisible ? 1 : 0.97, anchor: .bottom)
    .accessibilityElement(children: .contain)
  }

  private var objectiveText: Text {
    let copy = ChallengeObjectiveCopyBuilder.make(objective: challenge.objective, locale: locale)
    return copy.parts.reduce(Text("")) { result, part in
      if part.isHighlighted {
        return result
          + Text(verbatim: part.text)
          .foregroundColor(OutwitColors.action)
          .font(OutwitTypography.headlineLarge)
      }
      return result
        + Text(verbatim: part.text)
        .foregroundColor(OutwitColors.ink)
        .font(OutwitTypography.headlineLarge)
    }
  }

  private func updateActiveState() async {
    guard isActive else {
      contentIsVisible = false
      swipeOffset = 0
      return
    }

    if reduceMotion {
      contentIsVisible = true
    } else {
      withAnimation(.easeOut(duration: 0.35)) { contentIsVisible = true }
    }

    guard shouldPlaySwipeHint, !reduceMotion else { return }
    do {
      try await Task.sleep(for: .seconds(3))
      try Task.checkCancellation()
    } catch {
      return
    }

    onSwipeHintPlayed()
    for _ in 0..<2 {
      withAnimation(.easeOut(duration: 0.3)) { swipeOffset = -14 }
      try? await Task.sleep(for: .milliseconds(300))
      withAnimation(.easeIn(duration: 0.3)) { swipeOffset = 0 }
      try? await Task.sleep(for: .milliseconds(300))
    }
  }
}
