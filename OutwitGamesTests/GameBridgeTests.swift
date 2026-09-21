import Foundation
import Testing

@testable import OutwitGames

struct GameBridgeTests {
  @Test
  func parserAcceptsOnlyCanonicalHUDMessages() {
    #expect(GameHUDMessageParser.parse(["type": "outwit:ready", "protocol": 1]) == .ready)
    #expect(GameHUDMessageParser.parse(["type": "outwit:score", "score": 17]) == .score(17))
    #expect(
      GameHUDMessageParser.parse(["type": "outwit:time", "time": 2.5])
        == .time(seconds: 2.5)
    )
    #expect(
      GameHUDMessageParser.parse([
        [
          "type": "outwit:state",
          "state": ["score": 8, "status": "running"],
          "requestId": "native-0",
        ]
      ])
        == .state(
          values: ["score": .number(8), "status": .string("running")],
          requestID: "native-0"
        )
    )

    #expect(GameHUDMessageParser.parse(["type": "outwit:ready", "protocol": 2]) == nil)
    #expect(GameHUDMessageParser.parse(["type": "outwit:score", "score": true]) == nil)
    #expect(GameHUDMessageParser.parse(["type": "outwit:state", "state": "not-an-object"]) == nil)
    #expect(GameHUDMessageParser.parse(["type": "unknown", "score": 9]) == nil)
  }

  @Test
  func navigationPolicyAllowsOnlyTheEntryOrigin() throws {
    let entry = try #require(URL(string: "https://games.example.com:443/a/index.html"))
    let policy = GameNavigationPolicy(entryURL: entry)

    #expect(policy.allows(URL(string: "https://games.example.com/b/next.html")))
    #expect(!policy.allows(URL(string: "https://games.example.com:444/b/next.html")))
    #expect(!policy.allows(URL(string: "https://other.example.com/index.html")))
    #expect(!policy.allows(URL(string: "outwit://close")))
    #expect(!policy.allows(nil))
  }

  @Test
  func documentStartScriptContainsNativeHandlersAndCompatibilityShim() throws {
    let script = try GameBridge.documentStartScript(
      configuration: ["token": .string("socket-secret"), "gameId": .string("game-1")],
      lifecycle: .active
    )

    #expect(script.contains("window.OutwitHost"))
    #expect(script.contains("window.top !== window.self"))
    #expect(script.contains("window.webkit"))
    #expect(script.contains("flutter_inappwebview"))
    #expect(script.contains("socket-secret"))
  }
}
