import UIKit
import UserNotifications

nonisolated enum NotificationAuthorizationState: Equatable, Sendable {
  case notDetermined
  case denied
  case authorized
}

nonisolated protocol NotificationPermissionRequesting: Sendable {
  func authorizationState() async -> NotificationAuthorizationState
  func requestAuthorization() async throws -> Bool
  func openSettings() async
}

nonisolated struct NotificationPermissionRequester: NotificationPermissionRequesting {
  func authorizationState() async -> NotificationAuthorizationState {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined:
      return .notDetermined
    case .denied:
      return .denied
    case .authorized, .provisional, .ephemeral:
      return .authorized
    @unknown default:
      return .denied
    }
  }

  func requestAuthorization() async throws -> Bool {
    try await UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    )
  }

  func openSettings() async {
    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
    await MainActor.run {
      UIApplication.shared.open(url)
    }
  }
}
