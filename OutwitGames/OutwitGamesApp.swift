//
//  OutwitGamesApp.swift
//  OutwitGames
//
//  Created by Ayush yadav on 18/09/26.
//

import SwiftUI

@main
struct OutwitGamesApp: App {
  @State private var environment: AppEnvironment

  init() {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-ui-testing-login") {
        _environment = State(
          initialValue: AppEnvironment(
            coordinator: AppCoordinator(root: .login),
            sessionBootstrapper: UITestSessionBootstrapper(),
            authRepository: UITestAuthRepository()
          )
        )
        return
      }

      if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
        _environment = State(
          initialValue: AppEnvironment(
            sessionBootstrapper: UITestSessionBootstrapper()
          )
        )
        return
      }
    #endif

    _environment = State(initialValue: AppEnvironment())
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(environment)
        .environment(\.locale, environment.settings.locale)
    }
  }
}

#if DEBUG
  private nonisolated struct UITestSessionBootstrapper: SessionBootstrapping {
    func establishSession() async throws -> Bool { true }
  }

  private nonisolated struct UITestAuthRepository: AuthRepository {
    func sendOTP(to nationalPhoneNumber: String) async throws {}

    func verifyOTP(phone: String, code: String) async throws -> AuthUser {
      AuthUser(
        id: 91,
        kind: "registered",
        username: "ui-test-player",
        phone: "+91\(phone)",
        externalID: "ui-test-91"
      )
    }

    func loginToExistingAccount(phone: String, code: String) async throws -> AuthUser {
      try await verifyOTP(phone: phone, code: code)
    }
  }
#endif
