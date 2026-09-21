import Foundation

nonisolated struct PhoenixEvent: Equatable, Sendable {
  let reference: String?
  let topic: String
  let event: String
  let payload: [String: JSONValue]
}

nonisolated enum PhoenixSignal: Sendable {
  case event(PhoenixEvent)
  case failure(AppError)
  case closed
}

nonisolated enum PhoenixFrameCodec {
  static func encode(
    joinReference: String?,
    reference: String,
    topic: String,
    event: String,
    payload: [String: JSONValue]
  ) throws -> String {
    let frame: [JSONValue] = [
      joinReference.map(JSONValue.string) ?? .null,
      .string(reference),
      .string(topic),
      .string(event),
      .object(payload),
    ]
    let data = try JSONEncoder().encode(frame)
    guard let value = String(data: data, encoding: .utf8) else { throw AppError.parsing }
    return value
  }

  static func decode(_ value: String) throws -> PhoenixEvent {
    guard let data = value.data(using: .utf8) else { throw AppError.parsing }
    let frame = try JSONDecoder().decode([JSONValue].self, from: data)
    guard
      frame.count == 5,
      let topic = frame[2].stringValue,
      let event = frame[3].stringValue,
      let payload = frame[4].objectValue
    else {
      throw AppError.parsing
    }
    return PhoenixEvent(
      reference: frame[1].stringValue,
      topic: topic,
      event: event,
      payload: payload
    )
  }
}
