import Foundation

nonisolated struct APIQueryItem: Equatable, Sendable {
  let name: String
  let value: String
}

nonisolated struct APIRequest<Response: Sendable>: Sendable {
  let path: String
  let method: HTTPMethod
  let requiresAuthentication: Bool
  let queryItems: [APIQueryItem]
  let headers: [String: String]
  let body: Data?

  private let responseDecoder: @Sendable (Data) throws -> Response

  init(
    path: String,
    method: HTTPMethod = .get,
    requiresAuthentication: Bool = true,
    queryItems: [APIQueryItem] = [],
    headers: [String: String] = [:],
    body: Data? = nil,
    decode: @escaping @Sendable (Data) throws -> Response
  ) {
    self.path = path
    self.method = method
    self.requiresAuthentication = requiresAuthentication
    self.queryItems = queryItems
    self.headers = headers
    self.body = body
    responseDecoder = decode
  }

  func decodeResponse(from data: Data) throws -> Response {
    try responseDecoder(data)
  }
}

nonisolated extension APIRequest where Response: Decodable {
  init(
    path: String,
    method: HTTPMethod = .get,
    requiresAuthentication: Bool = true,
    queryItems: [APIQueryItem] = [],
    headers: [String: String] = [:],
    body: Data? = nil
  ) {
    self.init(
      path: path,
      method: method,
      requiresAuthentication: requiresAuthentication,
      queryItems: queryItems,
      headers: headers,
      body: body,
      decode: { data in
        try JSONDecoder.outwit.decode(Response.self, from: data)
      }
    )
  }

  init<Body: Encodable & Sendable>(
    path: String,
    method: HTTPMethod,
    requiresAuthentication: Bool = true,
    queryItems: [APIQueryItem] = [],
    headers: [String: String] = [:],
    jsonBody: Body
  ) throws {
    try self.init(
      path: path,
      method: method,
      requiresAuthentication: requiresAuthentication,
      queryItems: queryItems,
      headers: headers,
      body: JSONEncoder.outwit.encode(jsonBody)
    )
  }
}

nonisolated extension APIRequest {
  init<Payload: Decodable & Sendable>(
    path: String,
    method: HTTPMethod = .get,
    requiresAuthentication: Bool = true,
    queryItems: [APIQueryItem] = [],
    headers: [String: String] = [:],
    body: Data? = nil,
    decoding payload: Payload.Type,
    map: @escaping @Sendable (Payload) throws -> Response
  ) {
    self.init(
      path: path,
      method: method,
      requiresAuthentication: requiresAuthentication,
      queryItems: queryItems,
      headers: headers,
      body: body,
      decode: { data in
        let payload = try JSONDecoder.outwit.decode(Payload.self, from: data)
        return try map(payload)
      }
    )
  }

  init<Body: Encodable & Sendable, Payload: Decodable & Sendable>(
    path: String,
    method: HTTPMethod,
    requiresAuthentication: Bool = true,
    queryItems: [APIQueryItem] = [],
    headers: [String: String] = [:],
    jsonBody: Body,
    decoding payload: Payload.Type,
    map: @escaping @Sendable (Payload) throws -> Response
  ) throws {
    try self.init(
      path: path,
      method: method,
      requiresAuthentication: requiresAuthentication,
      queryItems: queryItems,
      headers: headers,
      body: JSONEncoder.outwit.encode(jsonBody),
      decoding: payload,
      map: map
    )
  }
}

extension JSONDecoder {
  fileprivate nonisolated static var outwit: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

extension JSONEncoder {
  fileprivate nonisolated static var outwit: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    return encoder
  }
}
