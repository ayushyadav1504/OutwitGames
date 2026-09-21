import Foundation

nonisolated enum SendOTPRequest {
  static func make(phone: String) throws -> APIRequest<Void> {
    try APIRequest(
      path: "/auth/otp/request",
      method: .post,
      requiresAuthentication: false,
      body: JSONEncoder().encode(SendOTPBody(phone: phone)),
      decode: { _ in () }
    )
  }
}

private nonisolated struct SendOTPBody: Encodable, Sendable {
  let phone: String
}
