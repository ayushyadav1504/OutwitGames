import SwiftUI

struct StartupView: View {
  @State private var viewModel: StartupViewModel

  init(
    sessionBootstrapper: any SessionBootstrapping,
    settings: AppSettings,
    coordinator: AppCoordinator
  ) {
    _viewModel = State(
      initialValue: StartupViewModel(
        sessionBootstrapper: sessionBootstrapper,
        settings: settings,
        coordinator: coordinator
      )
    )
  }

  var body: some View {
    ZStack {
      OutwitColors.red.ignoresSafeArea()

      SplashBrandAnimation()
        .offset(y: -6)

      if viewModel.state == .failed {
        VStack {
          Spacer()
          Button {
            Task { await viewModel.retry() }
          } label: {
            Label("common.retry", systemImage: "arrow.clockwise")
              .font(OutwitTypography.label)
              .foregroundStyle(.white)
              .padding(.horizontal, OutwitSpacing.x6)
              .frame(minWidth: 128, minHeight: 48)
              .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(.white, lineWidth: 1.5)
              }
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("startup-retry")
          .padding(.horizontal, OutwitSpacing.pageGutter)
          .padding(.bottom, OutwitSpacing.x6)
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .task {
      await viewModel.start()
    }
  }
}

#Preview {
  StartupView(
    sessionBootstrapper: PreviewSessionBootstrapper(),
    settings: AppSettings(),
    coordinator: AppCoordinator(root: .splash)
  )
}

private nonisolated struct PreviewSessionBootstrapper: SessionBootstrapping {
  func establishSession() async throws -> Bool { true }
}
