import Foundation

nonisolated struct NetworkErrorMapper: Sendable {
  func map(statusCode: Int?, backendMessage: String?, underlyingError: Error?) -> AppError {
    switch statusCode {
    case 401:
      return .unauthorized(messageKey: backendMessage ?? "unauthorized")
    case 403:
      return .forbidden(messageKey: backendMessage ?? "forbidden")
    case 400, 402, 404, 409, 422, 429:
      return .validation(messageKey: backendMessage ?? "something_wrong")
    case let statusCode? where statusCode >= 500:
      return .server(messageKey: backendMessage ?? "something_wrong")
    case .some:
      return .server(messageKey: backendMessage ?? "something_wrong")
    case nil:
      break
    }

    guard let urlError = underlyingError as? URLError else {
      return .server(messageKey: backendMessage ?? "something_wrong")
    }

    switch urlError.code {
    case .timedOut:
      return .networkTimeout
    case .cannotFindHost,
      .cannotConnectToHost,
      .dnsLookupFailed,
      .networkConnectionLost,
      .notConnectedToInternet,
      .internationalRoamingOff,
      .dataNotAllowed:
      return .noInternet
    default:
      return .server(messageKey: backendMessage ?? "something_wrong")
    }
  }
}
