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
    coordinator.replaceTop(with: .rewards)

    #expect(coordinator.path == [.onboarding, .rewards])

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
  }

  @Test
  func replacingAnEmptyPathChangesTheRoot() {
    let coordinator = AppCoordinator(root: .language)

    coordinator.replaceTop(with: .onboarding)

    #expect(coordinator.root == .onboarding)
    #expect(coordinator.path.isEmpty)
  }
}
