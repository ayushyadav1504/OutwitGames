import Foundation

nonisolated protocol SocketSession: Sendable {
  func start() async
  func setForeground(_ isForeground: Bool) async
  func events() async -> AsyncStream<PhoenixEvent>
  func acquire(topic: String) async throws -> [String: JSONValue]
  func release(topic: String) async
  func push(
    topic: String,
    event: String,
    payload: [String: JSONValue]
  ) async throws -> [String: JSONValue]
}

actor AppSocketSession: SocketSession {
  private struct SessionIdentity: Equatable, Sendable {
    let userID: Int
    let token: String
  }

  private let endpoint: URL
  private let tokenStore: any TokenStore
  private let transportFactory: any WebSocketTransportFactory

  private var started = false
  private var isForeground = true
  private var activeIdentity: SessionIdentity?
  private var connection: PhoenixConnection?
  private var connectionTask: Task<Void, any Error>?
  private var eventPump: Task<Void, Never>?
  private var sessionObserver: Task<Void, Never>?
  private var reconnectTask: Task<Void, Never>?
  private var reconnectAttempt = 0

  private var topicReferences: [String: Int] = [:]
  private var joinedTopics: Set<String> = []
  private var topicJoins: [String: Task<[String: JSONValue], any Error>] = [:]
  private var eventObservers: [UUID: AsyncStream<PhoenixEvent>.Continuation] = [:]

  init(
    endpoint: URL,
    tokenStore: any TokenStore,
    transportFactory: any WebSocketTransportFactory = URLSessionWebSocketTransportFactory()
  ) {
    self.endpoint = endpoint
    self.tokenStore = tokenStore
    self.transportFactory = transportFactory
  }

  deinit {
    sessionObserver?.cancel()
    reconnectTask?.cancel()
    eventPump?.cancel()
    connectionTask?.cancel()
  }

  func start() async {
    guard !started else { return }
    started = true
    let changes = await tokenStore.sessionChanges()
    sessionObserver = Task { [weak self] in
      for await session in changes {
        guard !Task.isCancelled else { return }
        await self?.sessionDidChange(session)
      }
    }
    await reconcile()
  }

  func setForeground(_ isForeground: Bool) async {
    guard self.isForeground != isForeground else { return }
    self.isForeground = isForeground
    if isForeground {
      reconnectAttempt = 0
      await reconcile()
    } else {
      await disconnect(clearTopicReferences: false)
    }
  }

  func events() -> AsyncStream<PhoenixEvent> {
    let identifier = UUID()
    return AsyncStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
      eventObservers[identifier] = continuation
      continuation.onTermination = { [weak self] _ in
        Task { await self?.removeEventObserver(identifier) }
      }
    }
  }

  func acquire(topic: String) async throws -> [String: JSONValue] {
    guard !topic.isEmpty else { throw AppError.invalidRequest }
    topicReferences[topic, default: 0] += 1
    do {
      try await ensureConnected()
      return try await ensureTopicJoined(topic)
    } catch {
      await release(topic: topic)
      throw error
    }
  }

  func release(topic: String) async {
    guard let count = topicReferences[topic] else { return }
    if count > 1 {
      topicReferences[topic] = count - 1
      return
    }
    topicReferences.removeValue(forKey: topic)

    if let joining = topicJoins[topic] {
      _ = try? await joining.value
    }
    topicJoins.removeValue(forKey: topic)
    guard joinedTopics.remove(topic) != nil, let connection else { return }
    await connection.leave(topic: topic)
  }

  func push(
    topic: String,
    event: String,
    payload: [String: JSONValue]
  ) async throws -> [String: JSONValue] {
    guard topicReferences[topic] != nil else { throw AppError.server() }
    try await ensureConnected()
    _ = try await ensureTopicJoined(topic)
    guard let connection else { throw AppError.server() }
    return try await connection.push(topic: topic, event: event, payload: payload)
  }

  private func ensureConnected() async throws {
    guard started, isForeground else { throw AppError.server() }
    let session = try await requiredSession()
    let identity = SessionIdentity(userID: session.user.id, token: session.socketToken)

    if activeIdentity == identity, connection != nil, connectionTask == nil { return }
    if let connectionTask {
      try await connectionTask.value
      return
    }
    if let activeIdentity, activeIdentity != identity {
      await disconnect(clearTopicReferences: activeIdentity.userID != identity.userID)
    }

    let task = Task { [weak self] in
      guard let self else { throw CancellationError() }
      try await self.establish(session: session, identity: identity)
    }
    connectionTask = task
    do {
      try await task.value
      connectionTask = nil
    } catch {
      connectionTask = nil
      throw error
    }
  }

  private func establish(session: AuthSession, identity: SessionIdentity) async throws {
    let connection = PhoenixConnection(
      endpoint: endpoint,
      transport: transportFactory.makeTransport()
    )
    self.connection = connection
    activeIdentity = identity
    startEventPump(for: connection)

    do {
      try await connection.connect(token: session.socketToken)
      _ = try await connection.join(topic: "user:\(session.user.id)")
      for topic in topicReferences.keys.sorted() {
        guard topicReferences[topic] != nil else { continue }
        _ = try await connection.join(topic: topic)
        joinedTopics.insert(topic)
      }
      reconnectAttempt = 0
    } catch {
      await connection.close()
      if self.connection === connection {
        self.connection = nil
        activeIdentity = nil
        joinedTopics.removeAll()
      }
      scheduleReconnect()
      throw Self.mapConnectionError(error)
    }
  }

  private func ensureTopicJoined(_ topic: String) async throws -> [String: JSONValue] {
    if joinedTopics.contains(topic) { return [:] }
    if let task = topicJoins[topic] { return try await task.value }
    guard let connection else { throw AppError.server() }

    let task = Task { try await connection.join(topic: topic) }
    topicJoins[topic] = task
    do {
      let response = try await task.value
      topicJoins.removeValue(forKey: topic)
      if topicReferences[topic] != nil, self.connection === connection {
        joinedTopics.insert(topic)
      } else {
        await connection.leave(topic: topic)
      }
      return response
    } catch {
      topicJoins.removeValue(forKey: topic)
      throw Self.mapConnectionError(error)
    }
  }

  private func startEventPump(for connection: PhoenixConnection) {
    eventPump?.cancel()
    eventPump = Task { [weak self] in
      for await signal in connection.signals {
        guard !Task.isCancelled else { return }
        switch signal {
        case .event(let event):
          await self?.publish(event)
        case .failure, .closed:
          await self?.connectionEnded(connection)
          return
        }
      }
    }
  }

  private func connectionEnded(_ endedConnection: PhoenixConnection) async {
    guard connection === endedConnection else { return }
    connection = nil
    activeIdentity = nil
    joinedTopics.removeAll()
    topicJoins.removeAll()
    eventPump = nil
    scheduleReconnect()
  }

  private func sessionDidChange(_ session: AuthSession?) async {
    let identity = session.flatMap { value in
      value.isComplete
        ? SessionIdentity(userID: value.user.id, token: value.socketToken)
        : nil
    }
    if let activeIdentity, activeIdentity != identity {
      let accountChanged = identity == nil || identity?.userID != activeIdentity.userID
      await disconnect(clearTopicReferences: accountChanged)
    }
    await reconcile()
  }

  private func reconcile() async {
    guard started, isForeground else { return }
    do {
      try await ensureConnected()
    } catch is CancellationError {
      return
    } catch {
      scheduleReconnect()
    }
  }

  private func scheduleReconnect() {
    guard started, isForeground, reconnectTask == nil else { return }
    reconnectAttempt += 1
    let delay = min(pow(2.0, Double(max(0, reconnectAttempt - 1))), 30)
    reconnectTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(delay))
      } catch {
        return
      }
      guard let self else { return }
      await self.clearReconnectTask()
      await self.reconcile()
    }
  }

  private func disconnect(clearTopicReferences: Bool) async {
    reconnectTask?.cancel()
    reconnectTask = nil
    connectionTask?.cancel()
    connectionTask = nil
    eventPump?.cancel()
    eventPump = nil
    for join in topicJoins.values { join.cancel() }
    topicJoins.removeAll()
    joinedTopics.removeAll()
    if clearTopicReferences { topicReferences.removeAll() }
    let connection = self.connection
    self.connection = nil
    activeIdentity = nil
    await connection?.close()
  }

  private func requiredSession() async throws -> AuthSession {
    guard let session = try await tokenStore.loadSession(), session.isComplete else {
      throw AppError.unauthorized()
    }
    return session
  }

  private func publish(_ event: PhoenixEvent) {
    for observer in eventObservers.values { observer.yield(event) }
  }

  private func removeEventObserver(_ identifier: UUID) {
    eventObservers.removeValue(forKey: identifier)
  }

  private func clearReconnectTask() {
    reconnectTask = nil
  }

  private static func mapConnectionError(_ error: any Error) -> AppError {
    if let error = error as? AppError { return error }
    return NetworkErrorMapper().map(statusCode: nil, backendMessage: nil, underlyingError: error)
  }
}

nonisolated struct UnavailableSocketSession: SocketSession {
  func start() async {}
  func setForeground(_ isForeground: Bool) async {}
  func events() async -> AsyncStream<PhoenixEvent> { AsyncStream { $0.finish() } }
  func acquire(topic: String) async throws -> [String: JSONValue] { throw AppError.server() }
  func release(topic: String) async {}
  func push(
    topic: String,
    event: String,
    payload: [String: JSONValue]
  ) async throws -> [String: JSONValue] {
    throw AppError.server()
  }
}
