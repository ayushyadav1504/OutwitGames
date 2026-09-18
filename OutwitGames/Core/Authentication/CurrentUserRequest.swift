import Foundation

nonisolated enum CurrentUserRequest {
  static func make() -> APIRequest<AuthUser> {
    APIRequest(
      path: "/me",
      decoding: CurrentUserPayload.self,
      map: { $0.user.toDomain() }
    )
  }
}

private nonisolated struct CurrentUserPayload: Decodable, Sendable {
  let user: AuthUserDTO
}
