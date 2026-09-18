import SwiftUI

struct LanguageOptionRow: View {
  let language: AppLanguage
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: OutwitSpacing.x4) {
        VStack(alignment: .leading, spacing: OutwitSpacing.x1) {
          Text(language.titleKey)
            .font(OutwitTypography.headlineSmall)
            .foregroundStyle(OutwitColors.ink)

          Text(language.subtitleKey)
            .font(OutwitTypography.bodySmall)
            .foregroundStyle(OutwitColors.mutedInk)
        }

        Spacer(minLength: OutwitSpacing.x4)

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(isSelected ? OutwitColors.action : OutwitColors.mutedInk)
          .accessibilityHidden(true)
      }
      .padding(OutwitSpacing.x4)
      .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
      .background(backgroundColor, in: cardShape)
      .overlay {
        cardShape.strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
      }
      .contentShape(cardShape)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityValue(
      isSelected
        ? Text("language.selection.selected")
        : Text("language.selection.not_selected")
    )
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  private var cardShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: OutwitRadius.card, style: .continuous)
  }

  private var backgroundColor: Color {
    isSelected ? OutwitColors.redTint : .white
  }

  private var borderColor: Color {
    isSelected ? OutwitColors.action : OutwitColors.paleBorder
  }
}

private extension AppLanguage {
  var titleKey: LocalizedStringKey {
    switch self {
    case .english: "language.option.english.title"
    case .hindi: "language.option.hindi.title"
    }
  }

  var subtitleKey: LocalizedStringKey {
    switch self {
    case .english: "language.option.english.subtitle"
    case .hindi: "language.option.hindi.subtitle"
    }
  }
}
