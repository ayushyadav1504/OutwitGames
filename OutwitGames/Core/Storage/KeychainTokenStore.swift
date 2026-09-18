import Foundation
import Security

actor KeychainTokenStore: TokenStore {
  private let service: String
  private let account = "authenticated-session"
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(service: String) {
    self.service = service
  }

  func loadSession() throws -> AuthSession? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw AppError.secureStorage
    }

    do {
      return try decoder.decode(AuthSession.self, from: data)
    } catch {
      throw AppError.secureStorage
    }
  }

  func saveSession(_ session: AuthSession) throws {
    let data: Data
    do {
      data = try encoder.encode(session)
    } catch {
      throw AppError.secureStorage
    }

    let attributes = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

    if updateStatus == errSecItemNotFound {
      var newItem = baseQuery
      newItem[kSecValueData as String] = data
      newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      guard SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess else {
        throw AppError.secureStorage
      }
      return
    }

    guard updateStatus == errSecSuccess else {
      throw AppError.secureStorage
    }
  }

  func saveUser(_ user: AuthUser) throws {
    guard var session = try loadSession() else {
      throw AppError.secureStorage
    }
    session.user = user
    try saveSession(session)
  }

  func clear() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw AppError.secureStorage
    }
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
