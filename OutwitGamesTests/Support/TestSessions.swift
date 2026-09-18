@testable import OutwitGames

enum TestSessions {
  static let original = AuthSession(
    user: AuthUser(
      id: 42,
      kind: "registered",
      username: "player",
      phone: "+910000000000",
      externalID: "external-42"
    ),
    apiToken: "old-api-token",
    socketToken: "old-socket-token",
    refreshToken: "old-refresh-token"
  )

  static let refreshed = AuthSession(
    user: original.user,
    apiToken: "new-api-token",
    socketToken: "new-socket-token",
    refreshToken: "new-refresh-token"
  )
}
