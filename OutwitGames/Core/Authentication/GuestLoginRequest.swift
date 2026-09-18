import Foundation

nonisolated enum GuestLoginRequest {
  static func make(
    device: DeviceSnapshot,
    referralCode: String? = nil
  ) throws -> APIRequest<AuthSession> {
    try APIRequest(
      path: "/auth/guest",
      method: .post,
      requiresAuthentication: false,
      jsonBody: GuestLoginBody(
        deviceID: device.id,
        deviceMetadata: device.metadata,
        referralCode: referralCode.flatMap(normalized)
      ),
      decoding: AuthSessionDTO.self,
      map: { $0.toDomain() }
    )
  }
}

private nonisolated struct GuestLoginBody: Encodable, Sendable {
  let deviceID: String
  let deviceMetadata: DeviceMetadata
  let referralCode: String?

  enum CodingKeys: String, CodingKey {
    case deviceID = "device_id"
    case deviceMetadata = "device_metadata"
    case referralCode = "referral_code"
  }
}

private nonisolated func normalized(_ value: String) -> String? {
  let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return normalizedValue.isEmpty ? nil : normalizedValue
}
