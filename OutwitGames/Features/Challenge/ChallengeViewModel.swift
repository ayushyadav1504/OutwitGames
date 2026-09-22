import Foundation
import Observation

enum ChallengeScreenState: Equatable, Sendable {
  case idle
  case preparing
  case playing(ChallengeLaunch)
  case result(ChallengeLaunch, ChallengeOutcome)
  case failed(messageKey: String)
}

enum ChallengeResultActionState: Equatable, Sendable {
  case idle
  case multiplying
  case retrying
}

@MainActor
@Observable
final class ChallengeViewModel {
  let challenge: FeedChallenge

  private let repository: any ChallengeRepository
  private let rewardedAds: any RewardedAdServing
  private let tokenStore: any TokenStore
  private let analytics: any AnalyticsTracking
  private let coordinator: AppCoordinator
  private var completionTask: Task<Void, Never>?
  private var actionTask: Task<Void, Never>?
  private var preloadTask: Task<Void, Never>?
  private var attempt = 1

  private(set) var state = ChallengeScreenState.idle
  private(set) var hud: ChallengeHUDState?
  private(set) var multiplier: ChallengeMultiplierViewData?
  private(set) var resultActionState = ChallengeResultActionState.idle
  private(set) var actionErrorKey: String?
  private(set) var isPageLoading = true
  private(set) var isExitPromptVisible = false

  init(
    repository: any ChallengeRepository,
    rewardedAds: any RewardedAdServing,
    tokenStore: any TokenStore,
    analytics: any AnalyticsTracking,
    coordinator: AppCoordinator,
    challenge: FeedChallenge
  ) {
    self.repository = repository
    self.rewardedAds = rewardedAds
    self.tokenStore = tokenStore
    self.analytics = analytics
    self.coordinator = coordinator
    self.challenge = challenge
  }

  func start() async {
    guard state == .idle || isFailed else { return }
    completionTask?.cancel()
    actionTask?.cancel()
    attempt = 1
    prepareForLaunch()
    state = .preparing

    do {
      let launch = try await repository.start(challenge)
      observeCompletion(of: launch)
      try Task.checkCancellation()
      hud = .initial(launch: launch)
      state = .playing(launch)
      preload(.retry)
    } catch is CancellationError {
      completionTask?.cancel()
      completionTask = nil
    } catch {
      state = .failed(messageKey: Self.messageKey(for: error))
    }
  }

  func retryStart() async {
    guard isFailed else { return }
    state = .idle
    await start()
  }

  func retryWithRewardedAd() {
    guard resultActionState == .idle, let result = currentResult, !result.outcome.won else {
      return
    }
    resultActionState = .retrying
    actionErrorKey = nil
    actionTask = Task { [weak self] in
      await self?.performRetry(from: result)
    }
  }

  func multiplyReward() {
    guard resultActionState == .idle, let result = currentResult, result.outcome.won else {
      return
    }
    resultActionState = .multiplying
    actionErrorKey = nil
    actionTask = Task { [weak self] in
      await self?.performMultiplier(from: result)
    }
  }

  func pageLoaded() {
    isPageLoading = false
  }

  func pageLoadFailed(_ messageKey: String) {
    completionTask?.cancel()
    completionTask = nil
    state = .failed(messageKey: messageKey)
  }

  func handle(_ event: GameHUDEvent) {
    guard case .playing = state, let hud else { return }
    self.hud = hud.applying(event)
  }

  func requestExit() {
    switch state {
    case .playing:
      isExitPromptVisible = true
    case .result, .failed, .idle, .preparing:
      close()
    }
  }

  func dismissExitPrompt() {
    isExitPromptVisible = false
  }

  func dismissActionError() {
    actionErrorKey = nil
  }

  func multiplierDidSettle() {
    guard let multiplier else { return }
    track(
      .bonusWheelSettled(
        challengeID: challenge.id,
        attempt: attempt,
        bonusCoins: multiplier.bonusCoins
      )
    )
  }

  func close() {
    cancel()
    coordinator.back()
  }

  func cancel() {
    completionTask?.cancel()
    actionTask?.cancel()
    preloadTask?.cancel()
    completionTask = nil
    actionTask = nil
    preloadTask = nil
  }

  func routeDidDisappear(currentRoute: AppRoute) {
    guard currentRoute != .challenge(challenge) else { return }
    cancel()
  }

  var shouldPauseGame: Bool {
    isExitPromptVisible || currentResult != nil
  }

  var isResultActionBusy: Bool { resultActionState != .idle }

  private var isFailed: Bool {
    if case .failed = state { return true }
    return false
  }

  private var currentResult: (launch: ChallengeLaunch, outcome: ChallengeOutcome)? {
    guard case .result(let launch, let outcome) = state else { return nil }
    return (launch, outcome)
  }

  private func prepareForLaunch() {
    isPageLoading = true
    isExitPromptVisible = false
    multiplier = nil
    resultActionState = .idle
    actionErrorKey = nil
  }

  private func observeCompletion(of launch: ChallengeLaunch) {
    completionTask = Task { [weak self, repository] in
      do {
        let outcome = try await repository.waitForEnd(of: launch)
        try Task.checkCancellation()
        guard let self else { return }
        hud = hud?.settled(
          won: outcome.won,
          runtimeMilliseconds: outcome.runtimeMilliseconds
        )
        state = .result(launch, outcome)
        track(
          .challengeFinished(
            challengeID: challenge.id,
            attempt: attempt,
            won: outcome.won,
            coins: outcome.totalCoins
          )
        )
        preload(outcome.won ? .multiplier : .retry)
      } catch is CancellationError {
        return
      } catch {
        guard let self else { return }
        state = .failed(messageKey: Self.messageKey(for: error))
      }
    }
  }

  private func performRetry(
    from result: (launch: ChallengeLaunch, outcome: ChallengeOutcome)
  ) async {
    defer { finishAction(for: result.launch) }
    do {
      guard let nonce = try await earnedNonce(for: result.launch, action: .retry) else { return }
      let nextLaunch = try await repository.retry(result.launch, nonce: nonce)
      try Task.checkCancellation()
      guard currentResult?.launch.gameID == result.launch.gameID else { return }
      attempt += 1
      prepareForLaunch()
      hud = .initial(launch: nextLaunch)
      state = .playing(nextLaunch)
      observeCompletion(of: nextLaunch)
      preload(.retry)
    } catch is CancellationError {
      return
    } catch {
      actionErrorKey = Self.messageKey(for: error)
    }
  }

  private func performMultiplier(
    from result: (launch: ChallengeLaunch, outcome: ChallengeOutcome)
  ) async {
    defer { finishAction(for: result.launch) }
    do {
      guard let nonce = try await earnedNonce(for: result.launch, action: .spin) else { return }
      let spin = try await repository.amplifyWin(result.launch, nonce: nonce)
      try Task.checkCancellation()
      guard currentResult?.launch.gameID == result.launch.gameID else { return }
      multiplier = ChallengeMultiplierViewData(outcome: result.outcome, spin: spin)
    } catch is CancellationError {
      return
    } catch {
      actionErrorKey = Self.messageKey(for: error)
    }
  }

  private func earnedNonce(
    for launch: ChallengeLaunch,
    action: ChallengeAdAction
  ) async throws -> String? {
    guard
      let session = try await tokenStore.loadSession(),
      !session.user.externalID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw AppError.validation(messageKey: "rewarded_ad_user_unavailable")
    }
    let placement: RewardedAdPlacement = action == .spin ? .multiplier : .retry
    track(
      .rewardedAd(
        "selected",
        placement: placement,
        challengeID: challenge.id,
        attempt: attempt
      )
    )

    async let adSession = repository.createAdSession(for: launch, action: action)
    await rewardedAds.load(placement)
    let nonce = try await adSession.nonce
    let outcome = await rewardedAds.show(
      placement,
      userID: session.user.externalID,
      customData: nonce
    )
    guard currentResult?.launch.gameID == launch.gameID else { return nil }

    let stage: String
    switch outcome {
    case .earned:
      stage = "earned"
    case .dismissed:
      stage = "dismissed"
      actionErrorKey = "rewarded_ad_not_earned"
    case .unavailable:
      stage = "unavailable"
      actionErrorKey = "rewarded_ad_unavailable"
    }
    track(
      .rewardedAd(
        stage,
        placement: placement,
        challengeID: challenge.id,
        attempt: attempt
      )
    )
    return outcome == .earned ? nonce : nil
  }

  private func preload(_ placement: RewardedAdPlacement) {
    preloadTask?.cancel()
    preloadTask = Task { [rewardedAds] in
      await rewardedAds.load(placement)
    }
  }

  private func finishAction(for launch: ChallengeLaunch) {
    if currentResult?.launch.gameID == launch.gameID {
      resultActionState = .idle
    }
    actionTask = nil
  }

  private func track(_ event: AnalyticsEvent) {
    Task { [analytics] in await analytics.track(event) }
  }

  private static func messageKey(for error: any Error) -> String {
    (error as? AppError)?.messageKey ?? AppError.server().messageKey
  }
}
