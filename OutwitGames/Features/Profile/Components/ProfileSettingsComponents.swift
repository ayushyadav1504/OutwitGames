import SwiftUI

struct ProfileIdentityView: View {
  let identity: ProfileIdentity

  var body: some View {
    HStack(spacing: OutwitSpacing.x3) {
      Image(systemName: "person.crop.circle.fill")
        .font(.system(size: 48, weight: .regular))
        .symbolRenderingMode(.palette)
        .foregroundStyle(OutwitColors.action, OutwitColors.redTint)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: OutwitSpacing.x1) {
        if identity.name.isEmpty {
          Text("profile.guest.name")
            .font(OutwitTypography.headlineSmall)
        } else {
          Text(verbatim: identity.name)
            .font(OutwitTypography.headlineSmall)
        }

        if identity.isRegistered {
          Text(verbatim: identity.phone)
            .font(OutwitTypography.bodySmall.bold())
            .foregroundStyle(.green)
        } else {
          Text("profile.guest.label")
            .font(OutwitTypography.bodySmall)
            .foregroundStyle(OutwitColors.mutedInk)
        }
      }
      .lineLimit(1)
    }
    .padding(.vertical, OutwitSpacing.x2)
    .accessibilityElement(children: .combine)
  }
}

struct ProfileSettingsRow: View {
  let icon: String
  let title: LocalizedStringKey
  var detail: LocalizedStringKey?
  var foregroundStyle: Color = OutwitColors.ink
  var showsProgress = false

  var body: some View {
    HStack(spacing: OutwitSpacing.x3) {
      Image(systemName: icon)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(foregroundStyle)
        .frame(width: 24)
        .accessibilityHidden(true)

      Text(title)
        .font(OutwitTypography.bodyEmphasized)
        .foregroundStyle(foregroundStyle)

      Spacer(minLength: OutwitSpacing.x3)

      if showsProgress {
        ProgressView()
          .tint(foregroundStyle)
      } else if let detail {
        Text(detail)
          .font(OutwitTypography.bodySmall)
          .foregroundStyle(OutwitColors.mutedInk)
      }
    }
    .frame(minHeight: 30)
    .contentShape(Rectangle())
  }
}
