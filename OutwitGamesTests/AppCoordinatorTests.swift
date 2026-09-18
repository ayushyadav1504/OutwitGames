import Testing

@testable import OutwitGames

@MainActor
struct AppCoordinatorTests {
  @Test
  func navigationCommandsKeepTypedState() {
    let coordinator = AppCoordinator()

    coordinator.push(.language)
    coordinator.push(.onboarding)
    coordinator.replaceTop(with: .login)

    #expect(coordinator.path == [.language, .login])

    coordinator.back()

    #expect(coordinator.path == [.language])
  }

  @Test
  func resettingNavigationDismissesPresentedSheet() {
    let coordinator = AppCoordinator()
    coordinator.present(.profile)

    coordinator.reset(to: .feed)

    #expect(coordinator.path == [.feed])
    #expect(coordinator.sheet == nil)
  }
}
