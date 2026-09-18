import SwiftUI

struct TutorialPageView: View {
  let page: TutorialPage
  let onCardAction: () -> Void

  var body: some View {
    Group {
      switch page {
      case .challenges:
        TutorialChallengesView(onBeat: onCardAction)
      case .rewards:
        TutorialRewardsView()
      case .swipe:
        TutorialSwipeView(onComplete: onCardAction)
      }
    }
    .frame(width: 360, height: 640, alignment: .topLeading)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(page.accessibilityKey)
    .accessibilityIdentifier("tutorial-page-\(page.rawValue)")
  }
}
