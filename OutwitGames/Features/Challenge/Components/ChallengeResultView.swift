import SwiftUI

struct ChallengeResultView: View {
  let launch: ChallengeLaunch
  let outcome: ChallengeOutcome
  let multiplier: ChallengeMultiplierViewData?
  let actionState: ChallengeResultActionState
  let onRetry: () -> Void
  let onMultiply: () -> Void
  let onContinue: () -> Void
  let onWheelSettled: () -> Void

  var body: some View {
    Group {
      if let multiplier {
        ChallengeMultiplierView(
          data: multiplier,
          onContinue: onContinue,
          onSettled: onWheelSettled
        )
      } else if outcome.won {
        ChallengeWinResultView(
          coins: outcome.totalCoins,
          actionState: actionState,
          onMultiply: onMultiply,
          onCollect: onContinue
        )
      } else {
        ChallengeNearMissResultView(
          data: .make(launch: launch, outcome: outcome),
          actionState: actionState,
          onRetry: onRetry,
          onHome: onContinue
        )
      }
    }
    .accessibilityIdentifier("challenge-result")
  }
}

private struct ChallengeWinResultView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  let coins: Int
  let actionState: ChallengeResultActionState
  let onMultiply: () -> Void
  let onCollect: () -> Void

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        ChallengeResultBackdrop(isWin: true)

        ScrollView(.vertical) {
          VStack(spacing: 0) {
            Spacer(minLength: 72)
            card
              .frame(width: min(292, geometry.size.width - 44))
              .padding(.bottom, 18)
          }
          .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .bottom)
        }
        .scrollIndicators(.hidden)
      }
    }
    .task {
      if reduceMotion {
        appeared = true
      } else {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { appeared = true }
      }
    }
  }

  private var card: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 1, green: 0.973, blue: 0.945), Color(red: 1, green: 0.949, blue: 0.922),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color(red: 0.91, green: 0.81, blue: 0.78).opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 26, y: 18)

      VStack(spacing: 0) {
        Text("challenge.result.won")
          .font(.custom("NunitoSans-ExtraBold", size: 39, relativeTo: .largeTitle))
          .tracking(-1.2)
          .foregroundStyle(OutwitColors.action)

        Image("OutwitCoin3D")
          .resizable()
          .scaledToFit()
          .frame(width: 118, height: 118)
          .rotation3DEffect(.degrees(appeared ? 0 : -180), axis: (x: 0, y: 1, z: 0))
          .scaleEffect(appeared ? 1 : 0.62)
          .opacity(appeared ? 1 : 0)
          .padding(.top, 5)

        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(coins, format: .number)
            .font(.custom("NunitoSans-ExtraBold", size: 42, relativeTo: .largeTitle))
            .tracking(-1.4)
          Text(coins == 1 ? "challenge.hud.coin" : "challenge.hud.coins")
            .font(.custom("NunitoSans-ExtraBold", size: 28, relativeTo: .title))
        }
        .foregroundStyle(OutwitColors.ink)
        .contentTransition(.numericText())

        Text("challenge.result.win_subtitle")
          .font(.custom("NunitoSans-SemiBold", size: 15, relativeTo: .body))
          .foregroundStyle(OutwitColors.mutedInk)
          .padding(.bottom, 14)

        ChallengeWatchAdButton(
          title: "challenge.result.multiply",
          isLoading: actionState == .multiplying,
          isEnabled: actionState == .idle,
          action: onMultiply
        )

        ChallengeSecondaryButton(
          title: String(localized: "challenge.result.collect"),
          isEnabled: actionState == .idle,
          action: onCollect
        )
        .padding(.top, 11)
      }
      .padding(.horizontal, 16)
      .padding(.top, 62)
      .padding(.bottom, 18)

      Image("ChallengeWinCrest")
        .resizable()
        .scaledToFit()
        .frame(width: 196, height: 110)
        .offset(y: -57)
        .scaleEffect(appeared ? 1 : 0.72)
        .opacity(appeared ? 1 : 0)
    }
    .offset(y: appeared ? 0 : 28)
    .opacity(appeared ? 1 : 0)
  }
}

private struct ChallengeNearMissResultView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  let data: ChallengeNearMissViewData
  let actionState: ChallengeResultActionState
  let onRetry: () -> Void
  let onHome: () -> Void

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        ChallengeResultBackdrop(isWin: false)

        ZStack(alignment: .top) {
          card
            .padding(.top, 48)
          Image("ChallengeNearMissSad")
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .shadow(color: .black.opacity(0.28), radius: 12, y: 10)
            .rotationEffect(.degrees(appeared ? 0 : -12))
            .scaleEffect(appeared ? 1 : 1.35)
        }
        .frame(width: min(292, geometry.size.width - 44))
        .padding(.bottom, 18)
        .offset(y: appeared ? 0 : 68)
        .opacity(appeared ? 1 : 0)
      }
    }
    .task {
      if reduceMotion {
        appeared = true
      } else {
        withAnimation(.spring(response: 0.58, dampingFraction: 0.8)) { appeared = true }
      }
    }
  }

  private var card: some View {
    VStack(spacing: 0) {
      Text(metricLabel)
        .font(.custom("NunitoSans-Bold", size: 14, relativeTo: .subheadline))
        .foregroundStyle(OutwitColors.mutedInk)
      Text(verbatim: metricValue)
        .font(.custom("NunitoSans-ExtraBold", size: 48, relativeTo: .largeTitle))
        .tracking(-2)
        .foregroundStyle(OutwitColors.ink)

      goalText
        .font(.custom("NunitoSans-SemiBold", size: 16, relativeTo: .body))
        .lineLimit(1)
        .minimumScaleFactor(0.64)
        .padding(.top, 6)
        .padding(.bottom, 18)

      ChallengeWatchAdButton(
        title: "challenge.result.retry",
        isLoading: actionState == .retrying,
        isEnabled: actionState == .idle,
        action: onRetry
      )

      ChallengeSecondaryButton(
        title: String(localized: "challenge.result.home"),
        isEnabled: actionState == .idle,
        action: onHome
      )
      .padding(.top, 11)
    }
    .padding(.horizontal, 16)
    .padding(.top, 70)
    .padding(.bottom, 18)
    .background(
      LinearGradient(
        colors: [
          Color(red: 1, green: 0.973, blue: 0.945), Color(red: 1, green: 0.949, blue: 0.922),
        ],
        startPoint: .top,
        endPoint: .bottom
      ),
      in: RoundedRectangle(cornerRadius: 28, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(Color(red: 0.91, green: 0.81, blue: 0.78).opacity(0.9), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.3), radius: 26, y: 18)
  }

  private var metricLabel: LocalizedStringKey {
    switch data.metric {
    case .score: "challenge.result.your_score"
    case .time: "challenge.result.your_time"
    }
  }

  private var metricValue: String {
    switch data.metric {
    case .score(let score): score.formatted()
    case .time(let milliseconds): Self.duration(milliseconds)
    }
  }

  private var goalText: Text {
    let prefix: LocalizedStringKey
    let target: String
    switch data.goal {
    case .score(let value):
      prefix = "challenge.result.goal_score"
      target = value.formatted()
    case .finish(let milliseconds):
      prefix = "challenge.result.goal_finish"
      target = Self.duration(milliseconds)
    case .moves(let value):
      prefix = "challenge.result.goal_finish"
      target = "\(value.formatted()) \(String(localized: "challenge.result.moves"))"
    case .survive(let milliseconds):
      prefix = "challenge.result.goal_survive"
      target = Self.duration(milliseconds)
    case .collect(let count, let metric):
      prefix = "challenge.result.goal_collect"
      target = [count.formatted(), metric.replacingOccurrences(of: "_", with: " ")]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }
    return Text(prefix)
      + Text(verbatim: " \(target) ").foregroundColor(OutwitColors.action).bold()
      + Text("challenge.result.to_win")
      + Text(verbatim: " \(data.rewardCoins.formatted()) ")
      .foregroundColor(OutwitColors.action).bold()
      + Text("challenge.hud.coins")
  }

  private static func duration(_ milliseconds: Int) -> String {
    let seconds = max(0, milliseconds) / 1_000
    guard seconds >= 60 else { return "\(seconds)s" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}

private struct ChallengeResultBackdrop: View {
  let isWin: Bool

  var body: some View {
    ZStack {
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: .black.opacity(isWin ? 0.14 : 0.28), location: 0.3),
          .init(color: Color(red: 0.07, green: 0.06, blue: 0.07).opacity(0.88), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      VStack {
        Spacer()
        LinearGradient(
          colors: [.clear, Color(red: 0.07, green: 0.06, blue: 0.07)],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 150)
      }
    }
    .ignoresSafeArea()
  }
}
