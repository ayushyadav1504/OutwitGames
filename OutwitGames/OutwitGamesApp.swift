//
//  OutwitGamesApp.swift
//  OutwitGames
//
//  Created by Ayush yadav on 18/09/26.
//

import SwiftUI

@main
struct OutwitGamesApp: App {
  @State private var environment = AppEnvironment()

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environment(environment)
        .environment(\.locale, environment.settings.locale)
    }
  }
}
