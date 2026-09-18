import Observation

@MainActor
@Observable
final class AppCoordinator {
  var path: [AppRoute] = []
  var sheet: AppSheet?

  func push(_ route: AppRoute) {
    path.append(route)
  }

  func replaceTop(with route: AppRoute) {
    if !path.isEmpty {
      path.removeLast()
    }
    path.append(route)
  }

  func reset(to route: AppRoute) {
    path = [route]
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
