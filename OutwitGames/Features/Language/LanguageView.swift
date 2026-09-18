import SwiftUI

struct LanguageView: View {
  @State private var viewModel: LanguageViewModel

  init(settings: AppSettings, coordinator: AppCoordinator) {
    _viewModel = State(
      initialValue: LanguageViewModel(settings: settings, coordinator: coordinator)
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Image("OutwitMarkPrimary")
          .resizable()
          .scaledToFit()
          .frame(width: 36, height: 36)
          .accessibilityHidden(true)

        Text("language.heading.english")
          .font(OutwitTypography.headlineLarge)
          .foregroundStyle(OutwitColors.ink)
          .padding(.top, OutwitSpacing.x6)
          .accessibilityIdentifier("language-title")

        Text("language.heading.hindi")
          .font(OutwitTypography.bodyEmphasized)
          .foregroundStyle(OutwitColors.mutedInk)
          .padding(.top, OutwitSpacing.x1)

        VStack(spacing: OutwitSpacing.x3) {
          ForEach(AppLanguage.allCases) { language in
            LanguageOptionRow(
              language: language,
              isSelected: viewModel.selectedLanguage == language,
              action: { viewModel.select(language) }
            )
          }
        }
        .padding(.top, OutwitSpacing.x8)

        Label("language.profile_hint", systemImage: "arrow.triangle.2.circlepath")
          .font(OutwitTypography.bodySmall.bold())
          .foregroundStyle(OutwitColors.action)
          .padding(.top, OutwitSpacing.x4)
      }
      .frame(maxWidth: 560, alignment: .leading)
      .padding(.horizontal, OutwitSpacing.pageGutter)
      .padding(.top, OutwitSpacing.x6)
      .padding(.bottom, OutwitSpacing.x8)
      .frame(maxWidth: .infinity)
    }
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom) {
      Button("common.continue", action: viewModel.continueFlow)
        .buttonStyle(.outwitPrimary)
        .accessibilityIdentifier("language-continue")
        .frame(maxWidth: 560)
        .padding(.horizontal, OutwitSpacing.pageGutter)
        .padding(.vertical, OutwitSpacing.x3)
        .frame(maxWidth: .infinity)
        .background(OutwitColors.softWhite.opacity(0.97))
    }
    .background(OutwitColors.softWhite.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }
}

#Preview {
  let settings = AppSettings()
  let coordinator = AppCoordinator(root: .language)

  return LanguageView(settings: settings, coordinator: coordinator)
    .environment(\.locale, settings.locale)
}
