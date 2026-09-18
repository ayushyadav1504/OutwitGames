import SwiftUI

struct OnboardingView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var permissionTask: Task<Void, Never>?
  @State private var viewModel: OnboardingViewModel

  init(
    settings: AppSettings,
    notifications: any NotificationPermissionRequesting,
    coordinator: AppCoordinator
  ) {
    _viewModel = State(
      initialValue: OnboardingViewModel(
        settings: settings,
        notifications: notifications,
        coordinator: coordinator
      )
    )
  }

  var body: some View {
    Group {
      switch viewModel.step {
      case .tutorial:
        tutorial
          .transition(reduceMotion ? .identity : .opacity)
      case .notifications:
        NotificationSoftAskView(
          isBusy: viewModel.isBusy,
          onTurnOn: requestNotificationPermission,
          onSkip: viewModel.skipNotifications
        )
        .transition(reduceMotion ? .identity : .opacity)
      }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.step)
    .toolbar(.hidden, for: .navigationBar)
    .onDisappear {
      permissionTask?.cancel()
      permissionTask = nil
    }
  }

  private var tutorial: some View {
    TutorialStage(
      selectedPage: tutorialPageBinding,
      onAdvance: advanceTutorial
    )
    .background(
      (TutorialPage(rawValue: viewModel.tutorialPage)?.background ?? OutwitColors.softWhite)
        .ignoresSafeArea()
    )
    .animation(
      reduceMotion ? nil : .linear(duration: 0.22),
      value: viewModel.tutorialPage
    )
  }

  private var tutorialPageBinding: Binding<Int> {
    Binding(
      get: { viewModel.tutorialPage },
      set: { viewModel.selectTutorialPage($0) }
    )
  }

  private func advanceTutorial() {
    if reduceMotion {
      viewModel.advanceTutorial()
    } else {
      withAnimation(.easeInOut(duration: 0.25)) {
        viewModel.advanceTutorial()
      }
    }
  }

  private func requestNotificationPermission() {
    guard permissionTask == nil else { return }
    permissionTask = Task {
      await viewModel.turnOnNotifications()
      permissionTask = nil
    }
  }
}

#Preview {
  let settings = AppSettings()
  OnboardingView(
    settings: settings,
    notifications: PreviewNotificationPermissionRequester(),
    coordinator: AppCoordinator(root: .onboarding)
  )
  .environment(\.locale, settings.locale)
}

private nonisolated struct PreviewNotificationPermissionRequester:
  NotificationPermissionRequesting
{
  func requestAuthorization() async throws -> Bool { true }
}
