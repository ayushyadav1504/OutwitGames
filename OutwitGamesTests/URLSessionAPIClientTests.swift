import Foundation
import Testing

@testable import OutwitGames

@Suite(.serialized)
struct URLSessionAPIClientTests {
  @Test
  func constructsAuthenticatedRequestAndDecodesResponse() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let observation = Locked(RequestObservation())
    let (client, session) = makeClient(tokenStore: store)
    defer {
      MockURLProtocol.reset()
      session.invalidateAndCancel()
    }

    MockURLProtocol.setHandler { request in
      observation.update {
        $0.path = request.url?.path
        $0.query = request.url?.query
        $0.method = request.httpMethod
        $0.authorization = request.value(forHTTPHeaderField: "Authorization")
        $0.clientHeader = request.value(forHTTPHeaderField: "X-Outwit-Client")
        $0.accept = request.value(forHTTPHeaderField: "Accept")
        $0.timeout = request.timeoutInterval
      }
      return (
        Self.response(for: request, statusCode: 200),
        Data(#"{"value":"ready"}"#.utf8)
      )
    }

    let request = APIRequest<TestPayload>(
      path: "/players",
      queryItems: [
        APIQueryItem(name: "page", value: "2"),
        APIQueryItem(name: "kind", value: "friend"),
      ],
      headers: ["X-Outwit-Client": "ios"]
    )
    let payload = try await client.send(request)
    let recorded = observation.read { $0 }

    #expect(payload == TestPayload(value: "ready"))
    #expect(recorded.path == "/api/players")
    #expect(recorded.query == "page=2&kind=friend")
    #expect(recorded.method == "GET")
    #expect(recorded.authorization == "Bearer old-api-token")
    #expect(recorded.clientHeader == "ios")
    #expect(recorded.accept == "application/json")
    #expect(recorded.timeout == 10)
  }

  @Test
  func refreshesUnauthorizedSessionAndRetriesOnce() async throws {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let observation = Locked(RefreshObservation())
    let (client, session) = makeClient(tokenStore: store)
    defer {
      MockURLProtocol.reset()
      session.invalidateAndCancel()
    }

    MockURLProtocol.setHandler { request in
      switch request.url?.path {
      case "/api/protected":
        let call = observation.update { state in
          state.protectedCalls += 1
          state.retryAuthorization = request.value(forHTTPHeaderField: "Authorization")
          return state.protectedCalls
        }
        if call == 1 {
          return (
            Self.response(for: request, statusCode: 401),
            Data(#"{"error":"unauthorized"}"#.utf8)
          )
        }
        return (
          Self.response(for: request, statusCode: 200),
          Data(#"{"value":"retried"}"#.utf8)
        )

      case "/api/auth/refresh":
        observation.update {
          $0.refreshCalls += 1
          $0.refreshBody = request.httpBody
          $0.refreshAuthorization = request.value(forHTTPHeaderField: "Authorization")
        }
        return (
          Self.response(for: request, statusCode: 200),
          Self.refreshedSessionData
        )

      default:
        return (
          Self.response(for: request, statusCode: 404),
          Data(#"{"error":"not_found"}"#.utf8)
        )
      }
    }

    let payload = try await client.send(APIRequest<TestPayload>(path: "/protected"))
    let recorded = observation.read { $0 }
    let refreshBody = try JSONDecoder().decode(
      RefreshBody.self,
      from: try #require(recorded.refreshBody)
    )

    #expect(payload == TestPayload(value: "retried"))
    #expect(recorded.protectedCalls == 2)
    #expect(recorded.refreshCalls == 1)
    #expect(recorded.retryAuthorization == "Bearer new-api-token")
    #expect(recorded.refreshAuthorization == nil)
    #expect(refreshBody.refreshToken == "old-refresh-token")
    #expect(await store.loadSession() == TestSessions.refreshed)
  }

  @Test
  func neverRetriesAnOriginalRequestMoreThanOnce() async {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let observation = Locked(RefreshObservation())
    let (client, session) = makeClient(tokenStore: store)
    defer {
      MockURLProtocol.reset()
      session.invalidateAndCancel()
    }

    MockURLProtocol.setHandler { request in
      if request.url?.path == "/api/auth/refresh" {
        observation.update { $0.refreshCalls += 1 }
        return (
          Self.response(for: request, statusCode: 200),
          Self.refreshedSessionData
        )
      }

      observation.update { $0.protectedCalls += 1 }
      return (
        Self.response(for: request, statusCode: 401),
        Data(#"{"error":"unauthorized"}"#.utf8)
      )
    }

    do {
      let _: TestPayload = try await client.send(APIRequest(path: "/protected"))
      Issue.record("Expected the retried request to remain unauthorized")
    } catch let error as AppError {
      #expect(error == .unauthorized(messageKey: "unauthorized"))
    } catch {
      Issue.record("Expected AppError, received \(error)")
    }

    let recorded = observation.read { $0 }
    #expect(recorded.protectedCalls == 2)
    #expect(recorded.refreshCalls == 1)
  }

  @Test
  func doesNotRefreshForOtherUnauthorizedBackendErrors() async {
    let store = InMemoryTokenStore(session: TestSessions.original)
    let observation = Locked(RefreshObservation())
    let (client, session) = makeClient(tokenStore: store)
    defer {
      MockURLProtocol.reset()
      session.invalidateAndCancel()
    }

    MockURLProtocol.setHandler { request in
      observation.update { $0.protectedCalls += 1 }
      return (
        Self.response(for: request, statusCode: 401),
        Data(#"{"error":"account_blocked"}"#.utf8)
      )
    }

    do {
      let _: TestPayload = try await client.send(APIRequest(path: "/protected"))
      Issue.record("Expected the backend authorization error")
    } catch let error as AppError {
      #expect(error == .unauthorized(messageKey: "account_blocked"))
    } catch {
      Issue.record("Expected AppError, received \(error)")
    }

    let recorded = observation.read { $0 }
    #expect(recorded.protectedCalls == 1)
    #expect(recorded.refreshCalls == 0)
    #expect(await store.loadSession() == TestSessions.original)
  }
}

extension URLSessionAPIClientTests {
  fileprivate func makeClient(
    tokenStore: any TokenStore
  ) -> (client: URLSessionAPIClient, session: URLSession) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return (
      URLSessionAPIClient(
        baseURL: URL(string: "https://staging.outwit.club/api")!,
        session: session,
        tokenStore: tokenStore
      ),
      session
    )
  }

  fileprivate nonisolated static func response(
    for request: URLRequest,
    statusCode: Int
  ) -> HTTPURLResponse {
    HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )!
  }

  fileprivate nonisolated static var refreshedSessionData: Data {
    Data(
      #"{"user":{"id":42,"kind":"registered","username":"player","phone":"+910000000000","external_id":"external-42"},"api_token":"new-api-token","socket_token":"new-socket-token","refresh_token":"new-refresh-token"}"#
        .utf8
    )
  }
}

private nonisolated struct TestPayload: Codable, Equatable, Sendable {
  let value: String
}

private nonisolated struct RefreshBody: Decodable, Sendable {
  let refreshToken: String

  enum CodingKeys: String, CodingKey {
    case refreshToken = "refresh_token"
  }
}

private nonisolated struct RequestObservation {
  var path: String?
  var query: String?
  var method: String?
  var authorization: String?
  var clientHeader: String?
  var accept: String?
  var timeout: TimeInterval?
}

private nonisolated struct RefreshObservation {
  var protectedCalls = 0
  var refreshCalls = 0
  var retryAuthorization: String?
  var refreshAuthorization: String?
  var refreshBody: Data?
}
