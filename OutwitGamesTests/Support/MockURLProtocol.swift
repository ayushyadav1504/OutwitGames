import Foundation

nonisolated final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

  private static let handler = Locked<Handler?>(nil)

  static func setHandler(_ handler: @escaping Handler) {
    Self.handler.update { $0 = handler }
  }

  static func reset() {
    handler.update { $0 = nil }
  }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let handler = Self.handler.read({ $0 }) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    do {
      let (response, data) = try handler(Self.materializingBody(in: request))
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}

  private static func materializingBody(in request: URLRequest) -> URLRequest {
    guard request.httpBody == nil, let stream = request.httpBodyStream else {
      return request
    }

    stream.open()
    defer { stream.close() }

    var body = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    while true {
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count > 0 else { break }
      body.append(buffer, count: count)
    }

    var materialized = request
    materialized.httpBodyStream = nil
    materialized.httpBody = body
    return materialized
  }
}
