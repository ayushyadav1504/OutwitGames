import Foundation

nonisolated enum VerifyOTPRequest {
  static func make(
    phone: String,
    code: String,
    device: DeviceSnapshot,
    referralCode: String? = nil
  ) throws -> APIRequest<AuthSession> {
    try APIRequest(
      path: "/auth/otp/verify",
      method: .post,
      requiresAuthentication: false,
      jsonBody: VerifyOTPBody(
        phone: phone,
        code: code,
        deviceMetadata: device.metadata,
        referralCode: referralCode.flatMap(normalized)
      ),
      decoding: AuthSessionDTO.self,
      map: { $0.toDomain() }
    )
  }
}

private nonisolated struct VerifyOTPBody: Encodable, Sendable {
  let phone: String
  let code: String
  let deviceMetadata: DeviceMetadata
  let referralCode: String?

  enum CodingKeys: String, CodingKey {
    case phone
    case code
    case deviceMetadata = "device_metadata"
    case referralCode = "referral_code"
  }
}

private nonisolated func normalized(_ value: String) -> String? {
  let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return normalizedValue.isEmpty ? nil : normalizedValue
}
