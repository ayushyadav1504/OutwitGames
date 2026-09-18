import Foundation

enum RefreshSessionRequest {
  nonisolated static func make(refreshToken: String) throws -> APIRequest<AuthSession> {
    try APIRequest(
      path: "/auth/refresh",
      method: .post,
      requiresAuthentication: false,
      jsonBody: Body(refreshToken: refreshToken),
      decoding: AuthSessionDTO.self,
      map: { dto in
        let session = dto.toDomain()
        guard session.isComplete else { throw AppError.parsing }
        return session
      }
    )
  }

  private nonisolated struct Body: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
      case refreshToken = "refresh_token"
    }
  }
}
