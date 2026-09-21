import Testing

@testable import OutwitGames

struct PhoenixFrameCodecTests {
  @Test
  func versionTwoFrameRoundTrips() throws {
    let raw = try PhoenixFrameCodec.encode(
      joinReference: "4",
      reference: "5",
      topic: "match:game-1",
      event: "query",
      payload: ["v": .number(1), "q": .string("challenge")]
    )
    let event = try PhoenixFrameCodec.decode(raw)

    #expect(event.reference == "5")
    #expect(event.topic == "match:game-1")
    #expect(event.event == "query")
    #expect(event.payload == ["v": .number(1), "q": .string("challenge")])
  }

  @Test
  func malformedFrameIsRejected() {
    #expect(throws: AppError.self) {
      _ = try PhoenixFrameCodec.decode(#"[null,"1","topic"]"#)
    }
  }
}
