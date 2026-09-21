import Foundation
import Testing

@testable import OutwitGames

struct FeedRequestTests {
  @Test
  func requestPreservesCursorContractAndMapsFeedData() throws {
    let request = FeedRequest.make(count: 5, cursor: "cursor-2")
    let page = try request.decodeResponse(from: Self.feedData)

    #expect(request.path == "/feed")
    #expect(request.method == .get)
    #expect(request.requiresAuthentication)
    #expect(
      request.queryItems == [
        APIQueryItem(name: "count", value: "5"),
        APIQueryItem(name: "cursor", value: "cursor-2"),
      ]
    )
    #expect(page.challenges.count == 1)
    #expect(page.challenges[0].id == 42)
    #expect(page.challenges[0].objective.target == 1200)
    #expect(page.challenges[0].rewardCoins == 8)
    #expect(
      page.challenges[0].backgroundVideoURL?.absoluteString == "https://cdn.example.com/hero.mp4")
    #expect(
      page.challenges[0].backgroundAudioURL?.absoluteString == "https://cdn.example.com/music.mp3")
    #expect(page.milestone?.next?.remaining == 300)
    #expect(page.nextCursor == "cursor-3")
  }

  @Test
  func paginationWithNoUsableCursorIsRejected() throws {
    let request = FeedRequest.make()
    let data = Data(#"{"feed":[],"pagination":{"has_more":true,"next_cursor":" "}}"#.utf8)

    do {
      _ = try request.decodeResponse(from: data)
      Issue.record("Expected malformed pagination to fail")
    } catch let error as AppError {
      #expect(error == .parsing)
    }
  }

  @Test
  func insecureMediaIsNeverSelectedForPlayback() throws {
    let challenge = try FeedRequest.make().decodeResponse(
      from: Data(
        #"{"feed":[{"challenge_id":7,"media":[{"tag":"hero","type":"video","url":"http://cdn.example.com/video.mp4"},{"tag":"music","type":"audio","url":"https://name:secret@cdn.example.com/music.mp3"}]}]}"#
          .utf8
      )
    ).challenges[0]

    #expect(challenge.backgroundVideoURL == nil)
    #expect(challenge.backgroundAudioURL == nil)
  }

  @Test
  func homeRequestMapsOnlyTheWalletNeededByTheFeed() throws {
    let request = HomeRequest.make()
    let wallet = try request.decodeResponse(
      from: Data(#"{"wallet":{"coins":245,"elixir":3},"games":[{"key":"ignored"}]}"#.utf8)
    )

    #expect(request.path == "/home")
    #expect(wallet == WalletBalance(coins: 245, elixir: 3))
  }

  private static let feedData = Data(
    #"""
    {
      "feed": [{
        "challenge_id": 42,
        "game_key": "quick-maths",
        "title": "Quick Maths",
        "objective": {"type": "min_score", "target": 1200},
        "difficulty": 1.5,
        "reward_coins": 8,
        "bundle": {"version": "3", "url": "https://games.example.com/math/", "entry": "index.html"},
        "media": [
          {"tag": "hero", "type": "video", "url": "https://cdn.example.com/hero.mp4", "thumbnail_url": "https://cdn.example.com/hero.jpg"},
          {"tag": "music", "type": "audio", "url": "https://cdn.example.com/music.mp3"}
        ]
      }],
      "milestone": {
        "lifetime_coins": 700,
        "next_milestone": {"label": "1K", "threshold": 1000, "reward_coins": 25, "remaining": 300}
      },
      "pagination": {"has_more": true, "next_cursor": "cursor-3"}
    }
    """#.utf8
  )
}
