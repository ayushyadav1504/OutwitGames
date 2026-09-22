import Testing

@testable import OutwitGames

@MainActor
struct AppCoordinatorTests {
  @Test
  func navigationCommandsKeepTypedState() {
    let coordinator = AppCoordinator()

    #expect(coordinator.root == .splash)

    coordinator.push(.onboarding)
    coordinator.push(.login)
    coordinator.replaceTop(with: .rewards(.home))

    #expect(coordinator.path == [.onboarding, .rewards(.home)])

    coordinator.back()

    #expect(coordinator.path == [.onboarding])
  }

  @Test
  func resettingNavigationDismissesPresentedSheet() {
    let coordinator = AppCoordinator(root: .onboarding)
    coordinator.push(.login)
    coordinator.present(.profile)

    coordinator.reset(to: .feed)

    #expect(coordinator.root == .feed)
    #expect(coordinator.path.isEmpty)
    #expect(coordinator.sheet == nil)
    #expect(coordinator.rootRevision == 1)
  }

  @Test
  func loginRestartRebuildsTheFeedRoot() {
    let coordinator = AppCoordinator(root: .feed)
    coordinator.push(.login)

    coordinator.restartAfterLogin()

    #expect(coordinator.root == .feed)
    #expect(coordinator.path.isEmpty)
    #expect(coordinator.rootRevision == 1)
  }

  @Test
  func replacingAnEmptyPathChangesTheRoot() {
    let coordinator = AppCoordinator(root: .language)

    coordinator.replaceTop(with: .onboarding)

    #expect(coordinator.root == .onboarding)
    #expect(coordinator.path.isEmpty)
  }
}
