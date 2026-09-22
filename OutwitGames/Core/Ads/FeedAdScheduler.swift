import Foundation

@MainActor
protocol FeedAdOpportunityReporting: AnyObject {
  func cardChanged()
}

@MainActor
final class NoOpFeedAdGate: FeedAdOpportunityReporting {
  func cardChanged() {}
}

@MainActor
final class AdCadence {
  let windowStart: Duration
  let interval: Duration
  let postChallengeGrace: Duration

  private(set) var elapsed: Duration = .zero
  private(set) var nextEligibleAt: Duration?
  private var challengeDepth = 0

  init(
    windowStart: Duration = .seconds(120),
    interval: Duration = .seconds(180),
    postChallengeGrace: Duration = .seconds(15)
  ) {
    self.windowStart = windowStart
    self.interval = interval
    self.postChallengeGrace = postChallengeGrace
  }

  var isDue: Bool {
    guard let nextEligibleAt else { return false }
    return elapsed >= nextEligibleAt && challengeDepth == 0
  }

  var isInChallenge: Bool { challengeDepth > 0 }

  func advance(_ amount: Duration) {
    guard amount > .zero, challengeDepth == 0 else { return }
    elapsed += amount
    if nextEligibleAt == nil, elapsed >= windowStart {
      nextEligibleAt = elapsed
    }
  }

  func recordImpression() {
    nextEligibleAt = elapsed + interval
  }

  func challengeStarted() {
    challengeDepth += 1
  }

  func challengeEnded() {
    guard challengeDepth > 0 else { return }
    challengeDepth -= 1
    guard challengeDepth == 0 else { return }
    let due = nextEligibleAt ?? windowStart
    nextEligibleAt = max(due, elapsed + postChallengeGrace)
  }

  func reset() {
    elapsed = .zero
    nextEligibleAt = nil
    challengeDepth = 0
  }
}

nonisolated struct FeedAdSessionState: Equatable, Sendable {
  let counts: Bool
  let showable: Bool
  let isInChallenge: Bool
  let sessionRevision: Int
}

@MainActor
final class FeedAdScheduler: FeedAdOpportunityReporting {
  private let ads: any InterstitialAdServing
  private let cadence: AdCadence
  private let analytics: any AnalyticsTracking
  private let tickInterval: Duration
  private let tickAmount: Duration
  private let preloadLead: Duration
  private let preloadRetryInterval: Duration

  private var timerTask: Task<Void, Never>?
  private var preloadTask: Task<Void, Never>?
  private var showTask: Task<Void, Never>?
  private var counts = false
  private var showable = false
  private var isInChallenge = false
  private var sessionRevision: Int?
  private var lastPreloadAt: Duration?
  private var isShowing = false

  init(
    ads: any InterstitialAdServing,
    cadence: AdCadence = AdCadence(),
    analytics: any AnalyticsTracking,
    tickInterval: Duration = .seconds(5),
    tickAmount: Duration? = nil,
    preloadLead: Duration = .seconds(30),
    preloadRetryInterval: Duration = .seconds(30)
  ) {
    self.ads = ads
    self.cadence = cadence
    self.analytics = analytics
    self.tickInterval = tickInterval
    self.tickAmount = tickAmount ?? tickInterval
    self.preloadLead = preloadLead
    self.preloadRetryInterval = preloadRetryInterval
  }

  func start() {
    guard timerTask == nil else { return }
    timerTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: tickInterval)
        } catch {
          return
        }
        tick()
      }
    }
  }

  func stop() {
    timerTask?.cancel()
    preloadTask?.cancel()
    showTask?.cancel()
    timerTask = nil
    preloadTask = nil
    showTask = nil
    isShowing = false
  }

  func update(_ state: FeedAdSessionState) {
    if sessionRevision != state.sessionRevision {
      sessionRevision = state.sessionRevision
      cadence.reset()
      lastPreloadAt = nil
      isInChallenge = false
    }

    if !isInChallenge, state.isInChallenge {
      cadence.challengeStarted()
    } else if isInChallenge, !state.isInChallenge {
      cadence.challengeEnded()
    }
    isInChallenge = state.isInChallenge
    counts = state.counts
    showable = state.showable
  }

  func tick() {
    guard counts else { return }
    cadence.advance(tickAmount)
    preloadIfNeeded()
  }

  func cardChanged() {
    guard showTask == nil else { return }
    showTask = Task { [weak self] in
      await self?.showIfDue()
      self?.showTask = nil
    }
  }

  func recordImpression() {
    cadence.recordImpression()
  }

  private func preloadIfNeeded() {
    guard !ads.isReady, preloadTask == nil else { return }
    let target = cadence.nextEligibleAt ?? cadence.windowStart
    guard cadence.elapsed + preloadLead >= target else { return }

    if let lastPreloadAt, lastPreloadAt <= cadence.elapsed,
      cadence.elapsed - lastPreloadAt < preloadRetryInterval
    {
      return
    }
    lastPreloadAt = cadence.elapsed
    preloadTask = Task { [weak self] in
      guard let self else { return }
      await ads.load()
      preloadTask = nil
    }
  }

  private func showIfDue() async {
    guard !isShowing, showable, cadence.isDue, ads.isReady else { return }
    isShowing = true
    defer { isShowing = false }

    if await ads.show() {
      cadence.recordImpression()
      await analytics.track(.feedInterstitialShown())
    } else {
      lastPreloadAt = nil
      preloadIfNeeded()
    }
  }
}
