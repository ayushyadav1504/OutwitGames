import Foundation
import Testing

@testable import OutwitGames

@Suite(.serialized)
struct KeychainTokenStoreTests {
  @Test
  func roundTripsAndClearsTheAuthenticatedSession() async throws {
    let store = KeychainTokenStore(service: "OutwitGamesTests.\(UUID().uuidString)")
    let expected = TestSessions.original

    try await store.clear()
    try await store.saveSession(expected)

    #expect(try await store.loadSession() == expected)

    let updatedUser = AuthUser(
      id: expected.user.id,
      kind: "registered",
      username: "updated-player",
      phone: expected.user.phone,
      externalID: expected.user.externalID
    )
    try await store.saveUser(updatedUser)

    #expect(try await store.loadSession()?.user == updatedUser)

    try await store.clear()
    #expect(try await store.loadSession() == nil)
  }
}
