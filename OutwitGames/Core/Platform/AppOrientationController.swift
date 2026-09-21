import UIKit

@MainActor
protocol ChallengeOrientationControlling: AnyObject {
  func beginPortraitChallenge()
  func endPortraitChallenge()
}

/// Owns the app delegate's orientation mask and applies per-scene geometry updates.
///
/// `shared` is intentionally confined to the UIKit adapter; feature code receives
/// the project-owned protocol through `AppEnvironment`.
@MainActor
final class AppOrientationController: ChallengeOrientationControlling {
  static let shared = AppOrientationController()

  private(set) var supportedOrientations: UIInterfaceOrientationMask = .all
  private var activePortraitChallenges = 0

  private init() {}

  func beginPortraitChallenge() {
    guard UIDevice.current.userInterfaceIdiom == .phone else { return }
    activePortraitChallenges += 1
    guard activePortraitChallenges == 1 else { return }
    apply(.portrait)
  }

  func endPortraitChallenge() {
    guard UIDevice.current.userInterfaceIdiom == .phone, activePortraitChallenges > 0 else {
      return
    }
    activePortraitChallenges -= 1
    guard activePortraitChallenges == 0 else { return }
    apply(.allButUpsideDown)
  }

  private func apply(_ orientations: UIInterfaceOrientationMask) {
    supportedOrientations = orientations
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in
        // A scene can reject a geometry change during a system transition.
        // The delegate mask still applies to the next orientation update.
      }
    }
  }
}

@MainActor
final class OutwitAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    AppOrientationController.shared.supportedOrientations
  }
}

extension UIWindowScene {
  fileprivate var keyWindow: UIWindow? {
    windows.first(where: \.isKeyWindow)
  }
}
