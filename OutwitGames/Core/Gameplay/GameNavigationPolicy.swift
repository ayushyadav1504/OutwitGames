import Foundation

nonisolated struct GameNavigationPolicy: Sendable {
  private let entryOrigin: Origin?

  init(entryURL: URL) {
    entryOrigin = Origin(url: entryURL)
  }

  func allows(_ targetURL: URL?) -> Bool {
    guard let targetURL, let targetOrigin = Origin(url: targetURL) else { return false }
    return targetOrigin == entryOrigin
  }

  private struct Origin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int

    init?(url: URL) {
      guard
        let scheme = url.scheme?.lowercased(),
        ["https", "http"].contains(scheme),
        let host = url.host?.lowercased(),
        !host.isEmpty,
        url.user == nil,
        url.password == nil
      else {
        return nil
      }
      self.scheme = scheme
      self.host = host
      self.port = url.port ?? (scheme == "https" ? 443 : 80)
    }
  }
}
