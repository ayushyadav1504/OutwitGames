import Foundation

actor PhoenixConnection {
  nonisolated let signals: AsyncStream<PhoenixSignal>

  private let endpoint: URL
  private let transport: any WebSocketTransport
  private let signalContinuation: AsyncStream<PhoenixSignal>.Continuation
  private let heartbeatInterval: Duration
  private let replyTimeout: Duration

  private var receiveTask: Task<Void, Never>?
  private var heartbeatTask: Task<Void, Never>?
  private var pendingReplies: [String: PhoenixReplyWaiter] = [:]
  private var joinReferences: [String: String] = [:]
  private var nextReference = 0
  private var isClosing = false

  init(
    endpoint: URL,
    transport: any WebSocketTransport,
    heartbeatInterval: Duration = .seconds(25),
    replyTimeout: Duration = .seconds(10)
  ) {
    self.endpoint = endpoint
    self.transport = transport
    self.heartbeatInterval = heartbeatInterval
    self.replyTimeout = replyTimeout
    let pair = AsyncStream.makeStream(
      of: PhoenixSignal.self,
      bufferingPolicy: .bufferingNewest(64)
    )
    signals = pair.stream
    signalContinuation = pair.continuation
  }

  func connect(token: String) async throws {
    guard receiveTask == nil, !token.isEmpty else { throw AppError.unauthorized() }
    try await transport.connect(to: try socketURL(token: token))
    receiveTask = Task { [weak self] in await self?.receiveMessages() }
    heartbeatTask = Task { [weak self] in await self?.sendHeartbeats() }
  }

  func join(topic: String) async throws -> [String: JSONValue] {
    if joinReferences[topic] != nil { return [:] }
    let reference = newReference()
    let reply = try await sendAndWait(
      joinReference: reference,
      reference: reference,
      topic: topic,
      event: "phx_join",
      payload: [:]
    )
    guard reply.payload["status"]?.stringValue == "ok" else {
      throw Self.replyError(reply.payload)
    }
    joinReferences[topic] = reference
    return reply.payload["response"]?.objectValue ?? [:]
  }

  func leave(topic: String) async {
    guard let joinReference = joinReferences.removeValue(forKey: topic) else { return }
    let reference = newReference()
    _ = try? await sendAndWait(
      joinReference: joinReference,
      reference: reference,
      topic: topic,
      event: "phx_leave",
      payload: [:],
      timeout: .seconds(2)
    )
  }

  func push(
    topic: String,
    event: String,
    payload: [String: JSONValue]
  ) async throws -> [String: JSONValue] {
    guard let joinReference = joinReferences[topic] else { throw AppError.server() }
    let reply = try await sendAndWait(
      joinReference: joinReference,
      reference: newReference(),
      topic: topic,
      event: event,
      payload: payload
    )
    let response = reply.payload["response"]?.objectValue ?? [:]
    guard reply.payload["status"]?.stringValue == "ok" else {
      throw AppError.validation(
        messageKey: response["reason"]?.stringValue ?? "something_wrong"
      )
    }
    return response
  }

  func close() async {
    guard !isClosing else { return }
    isClosing = true
    receiveTask?.cancel()
    heartbeatTask?.cancel()
    receiveTask = nil
    heartbeatTask = nil
    joinReferences.removeAll()
    let waiters = pendingReplies.values
    pendingReplies.removeAll()
    for waiter in waiters { await waiter.fail(.server()) }
    await transport.close()
    signalContinuation.yield(.closed)
    signalContinuation.finish()
  }

  private func sendAndWait(
    joinReference: String?,
    reference: String,
    topic: String,
    event: String,
    payload: [String: JSONValue],
    timeout: Duration? = nil
  ) async throws -> PhoenixEvent {
    let waiter = PhoenixReplyWaiter()
    pendingReplies[reference] = waiter
    defer { pendingReplies.removeValue(forKey: reference) }

    let frame = try PhoenixFrameCodec.encode(
      joinReference: joinReference,
      reference: reference,
      topic: topic,
      event: event,
      payload: payload
    )
    do {
      try await transport.send(frame)
    } catch {
      throw Self.mapTransportError(error)
    }

    return try await withThrowingTaskGroup(of: PhoenixEvent.self) { group in
      group.addTask { try await waiter.value() }
      group.addTask {
        try await Task.sleep(for: timeout ?? self.replyTimeout)
        throw AppError.networkTimeout
      }
      defer { group.cancelAll() }
      guard let reply = try await group.next() else { throw AppError.server() }
      return reply
    }
  }

  private func receiveMessages() async {
    do {
      while !Task.isCancelled {
        let raw = try await transport.receive()
        guard let event = try? PhoenixFrameCodec.decode(raw) else { continue }
        if event.event == "phx_reply", let reference = event.reference,
          let waiter = pendingReplies[reference]
        {
          await waiter.resolve(event)
        }
        signalContinuation.yield(.event(event))
      }
    } catch is CancellationError {
      return
    } catch {
      guard !isClosing else { return }
      let mapped = Self.mapTransportError(error)
      for waiter in pendingReplies.values { await waiter.fail(mapped) }
      pendingReplies.removeAll()
      signalContinuation.yield(.failure(mapped))
      signalContinuation.finish()
    }
  }

  private func sendHeartbeats() async {
    while !Task.isCancelled {
      do {
        try await Task.sleep(for: heartbeatInterval)
        let frame = try PhoenixFrameCodec.encode(
          joinReference: nil,
          reference: newReference(),
          topic: "phoenix",
          event: "heartbeat",
          payload: [:]
        )
        try await transport.send(frame)
      } catch is CancellationError {
        return
      } catch {
        // The receive loop owns connection-loss reporting and reconnection.
      }
    }
  }

  private func socketURL(token: String) throws -> URL {
    guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
      throw AppError.invalidRequest
    }
    let path = components.path.hasSuffix("/") ? components.path : components.path + "/"
    components.path = path + "websocket"
    var queryItems = components.queryItems ?? []
    queryItems.removeAll { $0.name == "token" || $0.name == "vsn" }
    queryItems.append(URLQueryItem(name: "token", value: token))
    queryItems.append(URLQueryItem(name: "vsn", value: "2.0.0"))
    components.queryItems = queryItems
    guard let url = components.url else { throw AppError.invalidRequest }
    return url
  }

  private func newReference() -> String {
    nextReference += 1
    return String(nextReference)
  }

  private static func replyError(_ payload: [String: JSONValue]) -> AppError {
    let response = payload["response"]?.objectValue
    return .validation(messageKey: response?["reason"]?.stringValue ?? "something_wrong")
  }

  private static func mapTransportError(_ error: any Error) -> AppError {
    if let error = error as? AppError { return error }
    return NetworkErrorMapper().map(statusCode: nil, backendMessage: nil, underlyingError: error)
  }
}

private actor PhoenixReplyWaiter {
  private enum Completion: Sendable {
    case event(PhoenixEvent)
    case failure(AppError)
    case cancelled
  }

  private var completion: Completion?
  private var continuation: CheckedContinuation<PhoenixEvent, any Error>?

  func value() async throws -> PhoenixEvent {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        if let completion {
          Self.resume(continuation, with: completion)
        } else {
          self.continuation = continuation
        }
      }
    } onCancel: {
      Task { await self.cancel() }
    }
  }

  func resolve(_ event: PhoenixEvent) {
    complete(.event(event))
  }

  func fail(_ error: AppError) {
    complete(.failure(error))
  }

  private func cancel() {
    complete(.cancelled)
  }

  private func complete(_ completion: Completion) {
    guard self.completion == nil else { return }
    self.completion = completion
    guard let continuation else { return }
    self.continuation = nil
    Self.resume(continuation, with: completion)
  }

  private static func resume(
    _ continuation: CheckedContinuation<PhoenixEvent, any Error>,
    with completion: Completion
  ) {
    switch completion {
    case .event(let event):
      continuation.resume(returning: event)
    case .failure(let error):
      continuation.resume(throwing: error)
    case .cancelled:
      continuation.resume(throwing: CancellationError())
    }
  }
}
