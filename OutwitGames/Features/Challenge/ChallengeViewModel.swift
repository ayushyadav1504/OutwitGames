import Observation

enum ChallengeScreenState: Equatable, Sendable {
  case idle
  case preparing
  case playing(ChallengeLaunch)
  case result(ChallengeLaunch, ChallengeOutcome)
  case failed(messageKey: String)
}

@MainActor
@Observable
final class ChallengeViewModel {
  let challenge: FeedChallenge

  private let repository: any ChallengeRepository
  private let coordinator: AppCoordinator
  private var completionTask: Task<Void, Never>?

  private(set) var state = ChallengeScreenState.idle
  private(set) var hud: ChallengeHUDState?
  private(set) var isPageLoading = true
  private(set) var isExitPromptVisible = false

  init(
    repository: any ChallengeRepository,
    coordinator: AppCoordinator,
    challenge: FeedChallenge
  ) {
    self.repository = repository
    self.coordinator = coordinator
    self.challenge = challenge
  }

  func start() async {
    guard state == .idle || isFailed else { return }
    completionTask?.cancel()
    isPageLoading = true
    isExitPromptVisible = false
    state = .preparing

    do {
      let launch = try await repository.start(challenge)
      // Transfer the match-topic lease to the completion task before checking
      // cancellation, so an exit on this exact boundary still releases it.
      observeCompletion(of: launch)
      try Task.checkCancellation()
      hud = .initial(launch: launch)
      state = .playing(launch)
    } catch is CancellationError {
      completionTask?.cancel()
      completionTask = nil
      return
    } catch {
      state = .failed(messageKey: Self.messageKey(for: error))
    }
  }

  func retry() async {
    guard isFailed else { return }
    state = .idle
    await start()
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

  func close() {
    cancel()
    coordinator.back()
  }

  func cancel() {
    completionTask?.cancel()
    completionTask = nil
  }

  var shouldPauseGame: Bool {
    isExitPromptVisible || isShowingResult
  }

  private var isFailed: Bool {
    if case .failed = state { return true }
    return false
  }

  private var isShowingResult: Bool {
    if case .result = state { return true }
    return false
  }

  private func observeCompletion(of launch: ChallengeLaunch) {
    completionTask = Task { [weak self, repository] in
      do {
        let outcome = try await repository.waitForEnd(of: launch)
        try Task.checkCancellation()
        guard let self else { return }
        state = .result(launch, outcome)
      } catch is CancellationError {
        return
      } catch {
        guard let self else { return }
        state = .failed(messageKey: Self.messageKey(for: error))
      }
    }
  }

  private static func messageKey(for error: any Error) -> String {
    (error as? AppError)?.messageKey ?? AppError.server().messageKey
  }
}
