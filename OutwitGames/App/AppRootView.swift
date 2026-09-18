import SwiftUI

struct AppRootView: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    @Bindable var coordinator = environment.coordinator

    NavigationStack(path: $coordinator.path) {
      FoundationLandingView()
        .navigationDestination(for: AppRoute.self) { route in
          PendingFeatureView(name: route.accessibilityName)
        }
    }
    .sheet(item: $coordinator.sheet) { sheet in
      PendingFeatureView(name: sheet.accessibilityName)
    }
  }
}

private struct FoundationLandingView: View {
  var body: some View {
    VStack(spacing: 8) {
      Text("Outwit Games")
        .font(.largeTitle.bold())
        .accessibilityIdentifier("app-title")

      Text("iOS foundation ready")
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}

private struct PendingFeatureView: View {
  let name: String

  var body: some View {
    ContentUnavailableView(
      name,
      systemImage: "hammer",
      description: Text("This feature will be added in its implementation checkpoint.")
    )
  }
}

#Preview {
  AppRootView()
    .environment(AppEnvironment())
}
