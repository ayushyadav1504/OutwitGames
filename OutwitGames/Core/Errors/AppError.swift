import Foundation

nonisolated enum AppError: Error, Equatable, Sendable {
  case noInternet
  case networkTimeout
  case unauthorized(messageKey: String = "unauthorized")
  case forbidden(messageKey: String = "forbidden")
  case validation(messageKey: String)
  case server(messageKey: String = "something_wrong")
  case parsing
  case invalidRequest
  case secureStorage

  var messageKey: String {
    switch self {
    case .noInternet:
      "no_internet"
    case .networkTimeout:
      "network_timeout"
    case .unauthorized(let messageKey),
      .forbidden(let messageKey),
      .validation(let messageKey),
      .server(let messageKey):
      messageKey
    case .parsing, .invalidRequest, .secureStorage:
      "something_wrong"
    }
  }
}
