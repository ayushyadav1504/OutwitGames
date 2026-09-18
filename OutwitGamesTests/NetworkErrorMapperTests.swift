import Foundation
import Testing

@testable import OutwitGames

struct NetworkErrorMapperTests {
  private let mapper = NetworkErrorMapper()

  @Test
  func mapsOfflineAndTimeoutTransportFailures() {
    #expect(
      mapper.map(
        statusCode: nil,
        backendMessage: nil,
        underlyingError: URLError(.notConnectedToInternet)
      ) == .noInternet
    )
    #expect(
      mapper.map(
        statusCode: nil,
        backendMessage: nil,
        underlyingError: URLError(.timedOut)
      ) == .networkTimeout
    )
  }

  @Test
  func preservesBackendErrorKeysForFeaturePresentation() {
    #expect(
      mapper.map(statusCode: 422, backendMessage: "phone_taken", underlyingError: nil)
        == .validation(messageKey: "phone_taken")
    )
    #expect(
      mapper.map(statusCode: 403, backendMessage: "forbidden", underlyingError: nil)
        == .forbidden(messageKey: "forbidden")
    )
  }
}
