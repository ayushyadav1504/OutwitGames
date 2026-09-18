import Foundation

typealias RefreshRequestFactory = @Sendable (String) throws -> APIRequest<AuthSession>

nonisolated final class URLSessionAPIClient: APIClient, Sendable {
  private let baseURL: URL
  private let session: URLSession
  private let tokenStore: any TokenStore
  private let errorMapper: NetworkErrorMapper
  private let refreshRequest: RefreshRequestFactory
  private let refreshCoordinator = SessionRefreshCoordinator()
  private let onSessionInvalidated: @Sendable () async -> Void

  init(
    baseURL: URL,
    session: URLSession = .shared,
    tokenStore: any TokenStore,
    errorMapper: NetworkErrorMapper = NetworkErrorMapper(),
    refreshRequest: @escaping RefreshRequestFactory = RefreshSessionRequest.make,
    onSessionInvalidated: @escaping @Sendable () async -> Void = {}
  ) {
    self.baseURL = baseURL
    self.session = session
    self.tokenStore = tokenStore
    self.errorMapper = errorMapper
    self.refreshRequest = refreshRequest
    self.onSessionInvalidated = onSessionInvalidated
  }

  func send<Response: Sendable>(_ request: APIRequest<Response>) async throws -> Response {
    do {
      return try await execute(request, mayRefresh: true)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as AppError {
      throw error
    } catch is DecodingError {
      throw AppError.parsing
    } catch {
      throw errorMapper.map(statusCode: nil, backendMessage: nil, underlyingError: error)
    }
  }

  private func execute<Response: Sendable>(
    _ request: APIRequest<Response>,
    mayRefresh: Bool
  ) async throws -> Response {
    try Task.checkCancellation()
    let result = try await perform(request)
    let backendMessage = Self.backendMessage(in: result.data)

    if mayRefresh,
      request.requiresAuthentication,
      result.response.statusCode == 401,
      backendMessage == "unauthorized"
    {
      try await refreshSession()
      try Task.checkCancellation()
      return try await execute(request, mayRefresh: false)
    }

    guard (200...299).contains(result.response.statusCode) else {
      throw errorMapper.map(
        statusCode: result.response.statusCode,
        backendMessage: backendMessage,
        underlyingError: nil
      )
    }

    return try request.decodeResponse(from: result.data)
  }

  private func perform<Response: Sendable>(
    _ request: APIRequest<Response>
  ) async throws -> HTTPResult {
    let urlRequest = try await makeURLRequest(for: request)

    do {
      let (data, response) = try await session.data(for: urlRequest)
      guard let response = response as? HTTPURLResponse else {
        throw AppError.parsing
      }
      return HTTPResult(data: data, response: response)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as URLError where error.code == .cancelled && Task.isCancelled {
      throw CancellationError()
    } catch let error as AppError {
      throw error
    } catch {
      throw errorMapper.map(statusCode: nil, backendMessage: nil, underlyingError: error)
    }
  }

  private func makeURLRequest<Response: Sendable>(
    for request: APIRequest<Response>
  ) async throws -> URLRequest {
    let url = try url(for: request)
    var urlRequest = URLRequest(url: url, timeoutInterval: 10)
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.httpBody = request.body
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

    if request.body != nil {
      urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    }
    for (name, value) in request.headers {
      urlRequest.setValue(value, forHTTPHeaderField: name)
    }

    if request.requiresAuthentication {
      let token = try await tokenStore.loadSession()?.apiToken
      if let token, !token.isEmpty {
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      }
    }
    return urlRequest
  }

  private func url<Response: Sendable>(for request: APIRequest<Response>) throws -> URL {
    guard
      !request.path.contains("://"),
      var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    else {
      throw AppError.invalidRequest
    }

    let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let requestPath = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    components.path = "/" + [basePath, requestPath].filter { !$0.isEmpty }.joined(separator: "/")
    components.queryItems = request.queryItems.map {
      URLQueryItem(name: $0.name, value: $0.value)
    }

    guard let url = components.url else {
      throw AppError.invalidRequest
    }
    return url
  }

  private func refreshSession() async throws {
    try await refreshCoordinator.refresh { [self] in
      do {
        guard
          let token = try await tokenStore.loadSession()?.refreshToken,
          !token.isEmpty
        else {
          throw AppError.unauthorized()
        }

        let request = try refreshRequest(token)
        let session = try await execute(request, mayRefresh: false)
        guard session.isComplete else { throw AppError.parsing }
        try await tokenStore.saveSession(session)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        try? await tokenStore.clear()
        await onSessionInvalidated()
        throw error
      }
    }
  }

  private static func backendMessage(in data: Data) -> String? {
    try? JSONDecoder().decode(BackendErrorPayload.self, from: data).error
  }
}

private nonisolated struct BackendErrorPayload: Decodable {
  let error: String
}

private nonisolated struct HTTPResult {
  let data: Data
  let response: HTTPURLResponse
}
