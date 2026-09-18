import UserNotifications

nonisolated protocol NotificationPermissionRequesting: Sendable {
  func requestAuthorization() async throws -> Bool
}

nonisolated struct NotificationPermissionRequester: NotificationPermissionRequesting {
  func requestAuthorization() async throws -> Bool {
    try await UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    )
  }
}
