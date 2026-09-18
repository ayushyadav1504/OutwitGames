@testable import OutwitGames

actor InMemoryTokenStore: TokenStore {
  private(set) var session: AuthSession?
  private(set) var clearCount = 0

  init(session: AuthSession? = nil) {
    self.session = session
  }

  func loadSession() -> AuthSession? {
    session
  }

  func saveSession(_ session: AuthSession) {
    self.session = session
  }

  func saveUser(_ user: AuthUser) throws {
    guard var session else { throw AppError.secureStorage }
    session.user = user
    self.session = session
  }

  func clear() {
    session = nil
    clearCount += 1
  }
}
