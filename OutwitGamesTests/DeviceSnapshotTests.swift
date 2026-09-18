import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct DeviceSnapshotTests {
  @Test
  func installationIdentityIsStableAndIOSSpecific() throws {
    let suiteName = "DeviceSnapshotTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let first = DeviceSnapshot.current(defaults: defaults)
    let second = DeviceSnapshot.current(defaults: defaults)

    #expect(first.id == second.id)
    #expect(first.id.count == 32)
    #expect(first.platform == "ios")
    #expect(first.metadata.platform == "ios")
  }
}
