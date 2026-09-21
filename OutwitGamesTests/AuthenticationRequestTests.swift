import Foundation
import Testing

@testable import OutwitGames

struct AuthenticationRequestTests {
  @Test
  func guestRequestPreservesTheBackendContract() throws {
    let device = DeviceSnapshot(
      id: "ios-installation-1",
      appVersion: "1.0.0",
      appBuild: "7",
      deviceModel: "iPhone",
      osName: "iOS",
      osVersion: "17.0",
      platform: "ios"
    )

    let request = try GuestLoginRequest.make(device: device, referralCode: " FRIEND42 ")
    let body = try JSONDecoder().decode(
      GuestRequestBody.self,
      from: try #require(request.body)
    )

    #expect(request.path == "/auth/guest")
    #expect(request.method == .post)
    #expect(!request.requiresAuthentication)
    #expect(body.deviceID == "ios-installation-1")
    #expect(body.referralCode == "FRIEND42")
    #expect(body.deviceMetadata.appVersion == "1.0.0")
    #expect(body.deviceMetadata.appBuild == "7")
    #expect(body.deviceMetadata.deviceModel == "iPhone")
    #expect(body.deviceMetadata.osName == "iOS")
    #expect(body.deviceMetadata.osVersion == "17.0")
    #expect(body.deviceMetadata.platform == "ios")
  }

  @Test
  func guestRequestOmitsAbsentReferralAndEmptyMetadata() throws {
    let device = DeviceSnapshot(
      id: "ios-installation-1",
      appVersion: "",
      appBuild: "",
      deviceModel: "",
      osName: "",
      osVersion: "",
      platform: "ios"
    )
    let request = try GuestLoginRequest.make(device: device)
    let data = try #require(request.body)
    let object = try #require(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    let metadata = try #require(object["device_metadata"] as? [String: String])

    #expect(object["referral_code"] == nil)
    #expect(metadata == ["platform": "ios"])
  }

  @Test
  func currentUserRequestMapsWrappedUserPayload() throws {
    let request = CurrentUserRequest.make()
    let data = Data(
      #"{"user":{"id":81,"kind":"registered","username":"ios-player","phone":"+919876543210","external_id":"external-81"}}"#
        .utf8
    )

    let user = try request.decodeResponse(from: data)

    #expect(request.path == "/me")
    #expect(request.method == .get)
    #expect(request.requiresAuthentication)
    #expect(user.id == 81)
    #expect(user.username == "ios-player")
    #expect(user.phone == "+919876543210")
  }

  @Test
  func sendOTPRequestUsesTheUnauthenticatedIOSPhoneContract() throws {
    let request = try SendOTPRequest.make(phone: "+919876543210")
    let body = try JSONDecoder().decode(
      PhoneBody.self,
      from: try #require(request.body)
    )

    #expect(request.path == "/auth/otp/request")
    #expect(request.method == .post)
    #expect(!request.requiresAuthentication)
    #expect(body.phone == "+919876543210")
    #expect(try request.decodeResponse(from: Data()) == ())
  }

  @Test
  func verifyOTPRequestIncludesDeviceMetadataAndNormalizedReferral() throws {
    let request = try VerifyOTPRequest.make(
      phone: "+919876543210",
      code: "2468",
      device: Self.device,
      referralCode: " FRIEND42 "
    )
    let body = try JSONDecoder().decode(
      VerifyRequestBody.self,
      from: try #require(request.body)
    )

    #expect(request.path == "/auth/otp/verify")
    #expect(request.method == .post)
    #expect(!request.requiresAuthentication)
    #expect(body.phone == "+919876543210")
    #expect(body.code == "2468")
    #expect(body.referralCode == "FRIEND42")
    #expect(body.deviceMetadata.platform == "ios")
  }

  @Test
  func upgradeGuestRequestRequiresAuthenticationAndMapsTheUser() throws {
    let request = try UpgradeGuestRequest.make(phone: "+919876543210", code: "2468")
    let data = Data(
      #"{"user":{"id":91,"kind":"registered","username":"secured-player","phone":"+919876543210","external_id":"external-91"}}"#
        .utf8
    )

    let user = try request.decodeResponse(from: data)

    #expect(request.path == "/upgrade/otp/verify")
    #expect(request.method == .post)
    #expect(request.requiresAuthentication)
    #expect(user.id == 91)
    #expect(user.isRegistered)
  }

  private static let device = DeviceSnapshot(
    id: "ios-device",
    appVersion: "1.0.0",
    appBuild: "8",
    deviceModel: "iPhone",
    osName: "iOS",
    osVersion: "17.0",
    platform: "ios"
  )
}

private nonisolated struct PhoneBody: Decodable, Sendable {
  let phone: String
}

private nonisolated struct VerifyRequestBody: Decodable, Sendable {
  let phone: String
  let code: String
  let deviceMetadata: GuestDeviceMetadata
  let referralCode: String?

  enum CodingKeys: String, CodingKey {
    case phone
    case code
    case deviceMetadata = "device_metadata"
    case referralCode = "referral_code"
  }
}

private nonisolated struct GuestRequestBody: Decodable, Sendable {
  let deviceID: String
  let deviceMetadata: GuestDeviceMetadata
  let referralCode: String?

  enum CodingKeys: String, CodingKey {
    case deviceID = "device_id"
    case deviceMetadata = "device_metadata"
    case referralCode = "referral_code"
  }
}

private nonisolated struct GuestDeviceMetadata: Decodable, Sendable {
  let appVersion: String
  let appBuild: String
  let deviceModel: String
  let osName: String
  let osVersion: String
  let platform: String
}
