import Foundation
import UIKit

nonisolated struct DeviceSnapshot: Equatable, Sendable {
  let id: String
  let appVersion: String
  let appBuild: String
  let deviceModel: String
  let osName: String
  let osVersion: String
  let platform: String

  var metadata: DeviceMetadata {
    DeviceMetadata(
      appVersion: normalized(appVersion),
      appBuild: normalized(appBuild),
      deviceModel: normalized(deviceModel),
      osName: normalized(osName),
      osVersion: normalized(osVersion),
      platform: normalized(platform)
    )
  }
}

nonisolated struct DeviceMetadata: Encodable, Equatable, Sendable {
  let appVersion: String?
  let appBuild: String?
  let deviceModel: String?
  let osName: String?
  let osVersion: String?
  let platform: String?
}

@MainActor
extension DeviceSnapshot {
  static func current(
    defaults: UserDefaults = .standard,
    bundle: Bundle = .main,
    device: UIDevice = .current
  ) -> DeviceSnapshot {
    DeviceSnapshot(
      id: installationID(in: defaults),
      appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "",
      appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
      deviceModel: device.model,
      osName: device.systemName,
      osVersion: device.systemVersion,
      platform: "ios"
    )
  }

  private static func installationID(in defaults: UserDefaults) -> String {
    if let value = defaults.string(forKey: Key.installationID).flatMap(normalized) {
      return value
    }

    let value = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    defaults.set(value, forKey: Key.installationID)
    return value
  }

  private enum Key {
    static let installationID = "device.installation_id"
  }
}

private nonisolated func normalized(_ value: String) -> String? {
  let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return normalizedValue.isEmpty ? nil : normalizedValue
}
