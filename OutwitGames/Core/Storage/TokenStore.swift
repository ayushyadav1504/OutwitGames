nonisolated protocol TokenStore: Sendable {
  func loadSession() async throws -> AuthSession?
  func saveSession(_ session: AuthSession) async throws
  func saveUser(_ user: AuthUser) async throws
  func clear() async throws
}

nonisolated extension TokenStore {
  func hasSession() async throws -> Bool {
    guard let session = try await loadSession() else { return false }
    return session.isComplete
  }
}
