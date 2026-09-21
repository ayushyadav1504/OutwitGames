import Foundation
import SwiftUI
import Testing

@testable import OutwitGames

struct AppSocketSessionTests {
  @Test
  func transientInactivePhaseKeepsTheAppWideSocketConnected() {
    #expect(AppSocketLifecyclePolicy.keepsConnection(for: .active))
    #expect(AppSocketLifecyclePolicy.keepsConnection(for: .inactive))
    #expect(!AppSocketLifecyclePolicy.keepsConnection(for: .background))
  }

  @Test
  func challengeTopicLeavesWithoutClosingAppWideUserSocket() async throws {
    let transport = ScriptedWebSocketTransport()
    let store = InMemoryTokenStore(session: TestSessions.original)
    let session = AppSocketSession(
      endpoint: URL(string: "wss://api.example.com/socket")!,
      tokenStore: store,
      transportFactory: SingleWebSocketTransportFactory(transport: transport)
    )

    await session.start()
    _ = try await session.acquire(topic: "match:game-1")
    await session.release(topic: "match:game-1")

    let frames = await transport.sentFrames
    #expect(
      frames.contains {
        $0.topic == "user:\(TestSessions.original.user.id)" && $0.event == "phx_join"
      })
    #expect(frames.contains { $0.topic == "match:game-1" && $0.event == "phx_join" })
    #expect(frames.contains { $0.topic == "match:game-1" && $0.event == "phx_leave" })
    #expect(await transport.connectCount == 1)
    #expect(await transport.closeCount == 0)

    await session.setForeground(false)
    #expect(await transport.closeCount == 1)
  }
}

private struct SingleWebSocketTransportFactory: WebSocketTransportFactory {
  let transport: ScriptedWebSocketTransport

  func makeTransport() -> any WebSocketTransport { transport }
}

private actor ScriptedWebSocketTransport: WebSocketTransport {
  private(set) var connectCount = 0
  private(set) var closeCount = 0
  private(set) var sentFrames: [PhoenixEvent] = []

  private var queuedMessages: [String] = []
  private var receivers: [CheckedContinuation<String, any Error>] = []

  func connect(to url: URL) throws {
    connectCount += 1
  }

  func send(_ text: String) async throws {
    let frame = try PhoenixFrameCodec.decode(text)
    sentFrames.append(frame)
    let response: [String: JSONValue]
    if frame.event == "query" {
      response = [
        "objective": .object(["type": .string("min_score"), "target": .number(12)])
      ]
    } else {
      response = [:]
    }
    let reply = try PhoenixFrameCodec.encode(
      joinReference: nil,
      reference: frame.reference ?? "0",
      topic: frame.topic,
      event: "phx_reply",
      payload: ["status": .string("ok"), "response": .object(response)]
    )
    enqueue(reply)
  }

  func receive() async throws -> String {
    if !queuedMessages.isEmpty { return queuedMessages.removeFirst() }
    return try await withCheckedThrowingContinuation { continuation in
      receivers.append(continuation)
    }
  }

  func close() {
    closeCount += 1
    let pending = receivers
    receivers.removeAll()
    for receiver in pending { receiver.resume(throwing: CancellationError()) }
  }

  private func enqueue(_ message: String) {
    guard !receivers.isEmpty else {
      queuedMessages.append(message)
      return
    }
    receivers.removeFirst().resume(returning: message)
  }
}
