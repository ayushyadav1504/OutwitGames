import CoreFoundation
import Foundation

nonisolated enum GameHUDEvent: Equatable, Sendable {
  case ready
  case state(values: [String: JSONValue], requestID: String?)
  case score(Int)
  case time(seconds: Double)
}

nonisolated enum GameHUDMessageParser {
  static func parse(_ value: Any) -> GameHUDEvent? {
    let payload: Any
    if let values = value as? [Any], values.count == 1 {
      payload = values[0]
    } else {
      payload = value
    }

    guard
      let object = payload as? [String: Any],
      let type = object["type"] as? String
    else {
      return nil
    }

    switch type {
    case "outwit:ready":
      guard integer(object["protocol"]) == 1 else { return nil }
      return .ready
    case "outwit:score":
      guard let score = integer(object["score"]) else { return nil }
      return .score(score)
    case "outwit:time":
      guard let seconds = number(object["time"]) else { return nil }
      return .time(seconds: seconds)
    case "outwit:state":
      guard let rawState = object["state"] as? [String: Any] else { return nil }
      if let requestID = object["requestId"], !(requestID is String) { return nil }
      guard let state = jsonObject(rawState) else { return nil }
      return .state(values: state, requestID: object["requestId"] as? String)
    default:
      return nil
    }
  }

  private static func jsonObject(_ value: [String: Any]) -> [String: JSONValue]? {
    var result: [String: JSONValue] = [:]
    for (key, rawValue) in value {
      guard let converted = jsonValue(rawValue) else { return nil }
      result[key] = converted
    }
    return result
  }

  private static func jsonValue(_ value: Any) -> JSONValue? {
    if value is NSNull { return .null }
    if let value = value as? String { return .string(value) }
    if let value = value as? Bool { return .bool(value) }
    if let value = number(value) { return .number(value) }
    if let value = value as? [String: Any], let object = jsonObject(value) {
      return .object(object)
    }
    if let value = value as? [Any] {
      var result: [JSONValue] = []
      for item in value {
        guard let converted = jsonValue(item) else { return nil }
        result.append(converted)
      }
      return .array(result)
    }
    return nil
  }

  private static func integer(_ value: Any?) -> Int? {
    guard let number = number(value), number.rounded(.towardZero) == number else { return nil }
    return Int(exactly: number)
  }

  private static func number(_ value: Any?) -> Double? {
    guard let value else { return nil }
    if let value = value as? NSNumber {
      guard CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
      let number = value.doubleValue
      return number.isFinite ? number : nil
    }
    return nil
  }
}
