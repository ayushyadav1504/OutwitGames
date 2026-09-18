import SwiftUI

struct TutorialPageIndicator: View {
  let selectedPage: Int
  let pageCount: Int
  let selectPage: (Int) -> Void

  var body: some View {
    HStack(spacing: 0) {
      ForEach(0..<pageCount, id: \.self) { page in
        Button {
          selectPage(page)
        } label: {
          Circle()
            .fill(
              page == selectedPage
                ? OutwitColors.action
                : OutwitColors.tutorialInactiveDot
            )
            .frame(
              width: page == selectedPage ? 12 : 8,
              height: page == selectedPage ? 12 : 8
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TutorialPage(rawValue: page)?.indicatorKey ?? "screen.onboarding.title")
        .accessibilityAddTraits(page == selectedPage ? .isSelected : [])
      }
    }
    .animation(.easeOut(duration: 0.22), value: selectedPage)
  }
}
