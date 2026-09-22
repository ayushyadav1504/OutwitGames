import Observation

@MainActor
@Observable
final class AppCoordinator {
  private(set) var root: AppRoute
  private(set) var rootRevision = 0
  var path: [AppRoute] = []
  var sheet: AppSheet?

  init(root: AppRoute = .splash) {
    self.root = root
  }

  func push(_ route: AppRoute) {
    path.append(route)
  }

  func replaceTop(with route: AppRoute) {
    guard !path.isEmpty else {
      root = route
      return
    }

    path.removeLast()
    path.append(route)
  }

  func reset(to route: AppRoute) {
    root = route
    rootRevision += 1
    path.removeAll()
    sheet = nil
  }

  func restartAfterLogin() {
    reset(to: .feed)
  }

  func openLoginFromProfile() {
    sheet = nil
    push(.login)
  }

  func restartAfterAccountExit() {
    reset(to: .splash)
  }

  func back() {
    guard !path.isEmpty else { return }
    path.removeLast()
  }

  func present(_ sheet: AppSheet) {
    self.sheet = sheet
  }

  func dismissSheet() {
    sheet = nil
  }
}
