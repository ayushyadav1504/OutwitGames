import Foundation

nonisolated enum UpgradeGuestRequest {
  static func make(phone: String, code: String) throws -> APIRequest<AuthUser> {
    try APIRequest(
      path: "/upgrade/otp/verify",
      method: .post,
      jsonBody: UpgradeGuestBody(phone: phone, code: code),
      decoding: UpgradeGuestPayload.self,
      map: { $0.user.toDomain() }
    )
  }
}

private nonisolated struct UpgradeGuestBody: Encodable, Sendable {
  let phone: String
  let code: String
}

private nonisolated struct UpgradeGuestPayload: Decodable, Sendable {
  let user: AuthUserDTO
}
