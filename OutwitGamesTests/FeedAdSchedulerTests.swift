import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct FeedAdSchedulerTests {
  @Test
  func cadenceStartsAtTwoMinutesAndWaitsThreeMinutesAfterAnImpression() {
    let cadence = AdCadence()

    cadence.advance(.seconds(119))
    #expect(!cadence.isDue)

    cadence.advance(.seconds(1))
    #expect(cadence.isDue)

    cadence.recordImpression()
    cadence.advance(.seconds(179))
    #expect(!cadence.isDue)

    cadence.advance(.seconds(1))
    #expect(cadence.isDue)
  }

  @Test
  func challengePausesCountingAndAddsGraceBeforeTheNextAd() {
    let cadence = AdCadence()
    cadence.advance(.seconds(120))
    #expect(cadence.isDue)

    cadence.challengeStarted()
    cadence.advance(.seconds(60))
    #expect(cadence.elapsed == .seconds(120))
    #expect(!cadence.isDue)

    cadence.challengeEnded()
    #expect(!cadence.isDue)
    cadence.advance(.seconds(14))
    #expect(!cadence.isDue)
    cadence.advance(.seconds(1))
    #expect(cadence.isDue)
  }

  @Test
  func schedulerShowsOnlyAtAVisibleCardBoundary() async {
    let ads = InterstitialAdFake(isReady: true)
    let analytics = AnalyticsSpy()
    let scheduler = FeedAdScheduler(
      ads: ads,
      cadence: AdCadence(
        windowStart: .seconds(10),
        interval: .seconds(20),
        postChallengeGrace: .seconds(2)
      ),
      analytics: analytics,
      tickInterval: .seconds(10),
      tickAmount: .seconds(10),
      preloadLead: .zero
    )
    scheduler.update(
      FeedAdSessionState(counts: true, showable: false, isInChallenge: false, sessionRevision: 1)
    )

    scheduler.tick()
    scheduler.cardChanged()
    await settleTasks()
    #expect(ads.showCalls == 0)

    scheduler.update(
      FeedAdSessionState(counts: true, showable: true, isInChallenge: false, sessionRevision: 1)
    )
    scheduler.cardChanged()
    await settleTasks()

    #expect(ads.showCalls == 1)
    #expect(await analytics.eventNames == ["ad_shown"])

    scheduler.cardChanged()
    await settleTasks()
    #expect(ads.showCalls == 1)
  }

  @Test
  func schedulerPreloadsBeforeTheFirstWindow() async {
    let ads = InterstitialAdFake(isReady: false)
    let scheduler = FeedAdScheduler(
      ads: ads,
      cadence: AdCadence(windowStart: .seconds(30)),
      analytics: NoOpAnalyticsTracker(),
      tickInterval: .seconds(10),
      tickAmount: .seconds(10),
      preloadLead: .seconds(20),
      preloadRetryInterval: .seconds(30)
    )
    scheduler.update(
      FeedAdSessionState(counts: true, showable: true, isInChallenge: false, sessionRevision: 1)
    )

    scheduler.tick()
    await settleTasks()

    #expect(ads.loadCalls == 1)
    #expect(ads.isReady)
  }

  private func settleTasks() async {
    for _ in 0..<20 { await Task.yield() }
  }
}

@MainActor
private final class InterstitialAdFake: InterstitialAdServing {
  var isReady: Bool
  private(set) var loadCalls = 0
  private(set) var showCalls = 0

  init(isReady: Bool) {
    self.isReady = isReady
  }

  func load() async {
    loadCalls += 1
    isReady = true
  }

  func show() async -> Bool {
    guard isReady else { return false }
    showCalls += 1
    isReady = false
    return true
  }
}

private actor AnalyticsSpy: AnalyticsTracking {
  private(set) var eventNames: [String] = []

  func track(_ event: AnalyticsEvent) async {
    eventNames.append(event.name)
  }
}
