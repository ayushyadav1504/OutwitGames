import SwiftUI

struct PhoneNumberField: View {
  @Binding var phone: String
  @FocusState.Binding var isFocused: Bool

  var body: some View {
    HStack(spacing: OutwitSpacing.x2) {
      Text(verbatim: "+91")
        .font(OutwitTypography.bodyEmphasized)
        .foregroundStyle(OutwitColors.ink)
        .accessibilityHidden(true)

      Rectangle()
        .fill(OutwitColors.paleBorder)
        .frame(width: 1, height: 24)
        .accessibilityHidden(true)

      TextField("login.phone.placeholder", text: $phone)
      .font(OutwitTypography.bodyEmphasized)
      .foregroundStyle(OutwitColors.ink)
      .keyboardType(.phonePad)
      .textContentType(.telephoneNumber)
      .focused($isFocused)
      .accessibilityLabel("login.phone.accessibility")
      .accessibilityIdentifier("login-phone-field")
    }
    .padding(.horizontal, OutwitSpacing.x4)
    .frame(minHeight: 56)
    .background(.white, in: fieldShape)
    .overlay {
      fieldShape
        .stroke(
          isFocused ? OutwitColors.action : OutwitColors.controlBorder,
          lineWidth: isFocused ? 2 : 1.5
        )
    }
  }

  private var fieldShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: OutwitRadius.input, style: .continuous)
  }
}
