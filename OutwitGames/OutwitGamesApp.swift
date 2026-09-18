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
#endif
