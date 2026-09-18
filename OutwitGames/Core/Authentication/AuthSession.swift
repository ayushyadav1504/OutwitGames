import Foundation

nonisolated struct AuthSession: Codable, Equatable, Sendable {
  var user: AuthUser
  let apiToken: String
  let socketToken: String
  let refreshToken: String

  var isComplete: Bool {
    user.id > 0
      && !apiToken.isEmpty
      && !socketToken.isEmpty
      && !refreshToken.isEmpty
  }
}

nonisolated struct AuthUser: Codable, Equatable, Sendable {
  let id: Int
  let kind: String
  let username: String
  let phone: String
  let externalID: String

  var isRegistered: Bool { kind == "registered" }
}
