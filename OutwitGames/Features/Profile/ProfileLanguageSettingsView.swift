import SwiftUI

struct ProfileLanguageSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var viewModel: ProfileViewModel

  var body: some View {
    List(AppLanguage.allCases) { language in
      Button {
        viewModel.selectLanguage(language)
        dismiss()
      } label: {
        HStack(spacing: OutwitSpacing.x3) {
          VStack(alignment: .leading, spacing: OutwitSpacing.x1) {
            Text(title(for: language))
              .font(OutwitTypography.bodyEmphasized)
              .foregroundStyle(OutwitColors.ink)
            Text(subtitle(for: language))
              .font(OutwitTypography.bodySmall)
              .foregroundStyle(OutwitColors.mutedInk)
          }

          Spacer()

          if viewModel.selectedLanguage == language {
            Image(systemName: "checkmark")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(OutwitColors.action)
              .accessibilityHidden(true)
          }
        }
        .contentShape(Rectangle())
      }
      .accessibilityAddTraits(viewModel.selectedLanguage == language ? .isSelected : [])
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(OutwitColors.softWhite)
    .navigationTitle("profile.language")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func title(for language: AppLanguage) -> LocalizedStringKey {
    switch language {
    case .english: "language.option.english.title"
    case .hindi: "language.option.hindi.title"
    }
  }

  private func subtitle(for language: AppLanguage) -> LocalizedStringKey {
    switch language {
    case .english: "language.option.english.subtitle"
    case .hindi: "language.option.hindi.subtitle"
    }
  }
}
