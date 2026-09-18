import Observation

@MainActor
@Observable
final class AppCoordinator {
  private(set) var root: AppRoute
  var path: [AppRoute] = []
  var sheet: AppSheet?

  init(root: AppRoute = .language) {
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
    path.removeAll()
    sheet = nil
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
