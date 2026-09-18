import Foundation

nonisolated struct AuthSessionDTO: Decodable, Sendable {
  let user: AuthUserDTO
  let apiToken: String
  let socketToken: String
  let refreshToken: String

  enum CodingKeys: String, CodingKey {
    case user
    case apiToken = "api_token"
    case socketToken = "socket_token"
    case refreshToken = "refresh_token"
  }

  func toDomain() -> AuthSession {
    AuthSession(
      user: user.toDomain(),
      apiToken: apiToken,
      socketToken: socketToken,
      refreshToken: refreshToken
    )
  }
}

nonisolated struct AuthUserDTO: Decodable, Sendable {
  let id: Int
  let kind: String
  let username: String
  let phone: String?
  let externalID: String?

  enum CodingKeys: String, CodingKey {
    case id
    case kind
    case username
    case phone
    case externalID = "external_id"
  }

  func toDomain() -> AuthUser {
    AuthUser(
      id: id,
      kind: kind,
      username: username,
      phone: phone ?? "",
      externalID: externalID ?? ""
    )
  }
}
