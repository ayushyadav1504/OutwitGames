enum AppSheet: String, Identifiable, Sendable {
  case profile
  case notificationSoftAsk

  var id: Self { self }

  var accessibilityName: String {
    switch self {
    case .profile: "Profile"
    case .notificationSoftAsk: "Notifications"
    }
  }
}
