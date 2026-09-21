import Foundation

nonisolated protocol WebSocketTransport: Sendable {
  func connect(to url: URL) async throws
  func send(_ text: String) async throws
  func receive() async throws -> String
  func close() async
}

nonisolated protocol WebSocketTransportFactory: Sendable {
  func makeTransport() -> any WebSocketTransport
}

nonisolated struct URLSessionWebSocketTransportFactory: WebSocketTransportFactory {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func makeTransport() -> any WebSocketTransport {
    URLSessionWebSocketTransport(session: session)
  }
}

private actor URLSessionWebSocketTransport: WebSocketTransport {
  private let session: URLSession
  private var task: URLSessionWebSocketTask?

  init(session: URLSession) {
    self.session = session
  }

  func connect(to url: URL) throws {
    guard task == nil else { throw AppError.invalidRequest }
    let task = session.webSocketTask(with: url)
    self.task = task
    task.resume()
  }

  func send(_ text: String) async throws {
    guard let task else { throw AppError.server() }
    try await task.send(.string(text))
  }

  func receive() async throws -> String {
    guard let task else { throw AppError.server() }
    switch try await task.receive() {
    case .string(let value):
      return value
    case .data(let data):
      guard let value = String(data: data, encoding: .utf8) else { throw AppError.parsing }
      return value
    @unknown default:
      throw AppError.parsing
    }
  }

  func close() {
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
  }
}
