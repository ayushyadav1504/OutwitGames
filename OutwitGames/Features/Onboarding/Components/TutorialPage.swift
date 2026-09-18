import SwiftUI

enum TutorialPage: Int, CaseIterable, Identifiable, Sendable {
  case challenges
  case rewards
  case swipe

  var id: Int { rawValue }

  var titleKey: LocalizedStringKey {
    switch self {
    case .challenges: "onboarding.challenges.title"
    case .rewards: "onboarding.rewards.title"
    case .swipe: "onboarding.swipe.title"
    }
  }

  var accentKey: LocalizedStringKey {
    switch self {
    case .challenges: "onboarding.challenges.accent"
    case .rewards: "onboarding.rewards.accent"
    case .swipe: "onboarding.swipe.accent"
    }
  }

  var bodyKey: LocalizedStringKey {
    switch self {
    case .challenges: "onboarding.challenges.body"
    case .rewards: "onboarding.rewards.body"
    case .swipe: "onboarding.swipe.body"
    }
  }

  var accessibilityKey: LocalizedStringKey {
    switch self {
    case .challenges: "onboarding.challenges.accessibility"
    case .rewards: "onboarding.rewards.accessibility"
    case .swipe: "onboarding.swipe.accessibility"
    }
  }

  var indicatorKey: LocalizedStringKey {
    switch self {
    case .challenges: "onboarding.page.first"
    case .rewards: "onboarding.page.second"
    case .swipe: "onboarding.page.third"
    }
  }

  var background: Color {
    switch self {
    case .challenges: OutwitColors.tutorialFirst
    case .rewards: OutwitColors.tutorialSecond
    case .swipe: OutwitColors.tutorialThird
    }
  }
}
