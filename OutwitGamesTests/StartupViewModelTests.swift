import Foundation
import Testing

@testable import OutwitGames

@MainActor
struct StartupViewModelTests {
  @Test
  func successfulBootstrapRoutesToLanguageWhenItIsMissing() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    let viewModel = StartupViewModel(
      sessionBootstrapper: StartupBootstrapper(results: [.success(true)]),
      settings: context.settings,
      coordinator: context.coordinator,
      minimumDisplayDuration: .zero
    )

    await viewModel.start()

    #expect(context.coordinator.root == .language)
  }

  @Test
  func successfulBootstrapRoutesToIncompleteOnboarding() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    context.settings.setLanguage(.hindi)
    let viewModel = StartupViewModel(
      sessionBootstrapper: StartupBootstrapper(results: [.success(true)]),
      settings: context.settings,
      coordinator: context.coordinator,
      minimumDisplayDuration: .zero
    )

    await viewModel.start()

    #expect(context.coordinator.root == .onboarding)
  }

  @Test
  func successfulBootstrapRoutesToFeedAfterOnboarding() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    context.settings.setLanguage(.english)
    context.settings.markOnboardingComplete()
    let viewModel = StartupViewModel(
      sessionBootstrapper: StartupBootstrapper(results: [.success(true)]),
      settings: context.settings,
      coordinator: context.coordinator,
      minimumDisplayDuration: .zero
    )

    await viewModel.start()

    #expect(context.coordinator.root == .feed)
  }

  @Test
  func failedBootstrapCanRetry() async throws {
    let context = try makeContext()
    defer { context.cleanUp() }
    let bootstrapper = StartupBootstrapper(results: [.success(false), .success(true)])
    let viewModel = StartupViewModel(
      sessionBootstrapper: bootstrapper,
      settings: context.settings,
      coordinator: context.coordinator,
      minimumDisplayDuration: .zero
    )

    await viewModel.start()
    #expect(viewModel.state == .failed)
    #expect(context.coordinator.root == .splash)

    await viewModel.retry()

    #expect(context.coordinator.root == .language)
    #expect(await bootstrapper.callCount == 2)
  }

  private func makeContext() throws -> StartupTestContext {
    let suiteName = "StartupViewModelTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return StartupTestContext(
      settings: AppSettings(defaults: defaults),
      coordinator: AppCoordinator(root: .splash),
      defaults: defaults,
      suiteName: suiteName
    )
  }
}

private struct StartupTestContext {
  let settings: AppSettings
  let coordinator: AppCoordinator
  let defaults: UserDefaults
  let suiteName: String

  func cleanUp() {
    defaults.removePersistentDomain(forName: suiteName)
  }
}

private actor StartupBootstrapper: SessionBootstrapping {
  private var results: [Result<Bool, StartupTestError>]
  private(set) var callCount = 0

  init(results: [Result<Bool, StartupTestError>]) {
    self.results = results
  }

  func establishSession() async throws -> Bool {
    callCount += 1
    guard !results.isEmpty else { throw StartupTestError.missingResult }
    return try results.removeFirst().get()
  }
}

private enum StartupTestError: Error {
  case missingResult
}
