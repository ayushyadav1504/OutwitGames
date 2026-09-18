nonisolated protocol APIClient: Sendable {
  func send<Response: Sendable>(_ request: APIRequest<Response>) async throws -> Response
}
