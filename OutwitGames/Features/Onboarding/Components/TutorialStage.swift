import SwiftUI

struct TutorialStage: View {
  @Binding var selectedPage: Int
  let onAdvance: () -> Void

  private let designSize = CGSize(width: 360, height: 640)

  var body: some View {
    GeometryReader { geometry in
      let scale = min(
        geometry.size.width / designSize.width,
        geometry.size.height / designSize.height
      )
      let fittedSize = CGSize(
        width: designSize.width * scale,
        height: designSize.height * scale
      )

      ZStack(alignment: .topLeading) {
        TabView(selection: $selectedPage) {
          ForEach(TutorialPage.allCases) { page in
            TutorialPageView(page: page, onCardAction: onAdvance)
              .tag(page.rawValue)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(width: designSize.width, height: designSize.height)

        TutorialPageIndicator(
          selectedPage: selectedPage,
          pageCount: TutorialPage.allCases.count,
          selectPage: { selectedPage = $0 }
        )
        .frame(width: 116, height: 32)
        .position(x: 180, y: 553)

        TutorialPage(rawValue: selectedPage)?.background
          .frame(width: designSize.width, height: 72)
          .position(x: designSize.width / 2, y: 604)

        TutorialActionButton(
          title: selectedPage == TutorialPage.allCases.count - 1
            ? "onboarding.action.start"
            : "onboarding.action.next",
          showArrow: selectedPage < TutorialPage.allCases.count - 1,
          action: onAdvance
        )
        .accessibilityIdentifier("onboarding-continue")
        .frame(width: 320)
        .position(x: 180, y: 602)
      }
      .frame(width: designSize.width, height: designSize.height)
      // The tutorial is authored as one illustration and scales uniformly so
      // its cards, typography, and touch targets keep their intended ratios.
      .scaleEffect(scale)
      .frame(width: fittedSize.width, height: fittedSize.height)
      .position(x: geometry.size.width / 2, y: fittedSize.height / 2)
    }
  }
}
