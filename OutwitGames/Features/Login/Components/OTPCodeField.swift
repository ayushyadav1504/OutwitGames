import SwiftUI

struct OTPCodeField: View {
  @Binding var code: String
  @FocusState.Binding var isFocused: Bool

  var body: some View {
    ZStack {
      HStack(spacing: OutwitSpacing.x2) {
        ForEach(0..<LoginViewModel.otpLength, id: \.self) { index in
          digitBox(at: index)
        }
      }
      .allowsHitTesting(false)

      TextField("", text: $code)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .autocorrectionDisabled()
        .focused($isFocused)
        .foregroundStyle(.clear)
        .tint(.clear)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityLabel("login.otp.accessibility")
        .accessibilityValue(code)
        .accessibilityIdentifier("login-otp-field")
    }
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    .onTapGesture {
      isFocused = true
    }
  }

  private func digitBox(at index: Int) -> some View {
    let digit = index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : ""
    let activeIndex = min(code.count, LoginViewModel.otpLength - 1)
    let isActive = isFocused && index == activeIndex

    return Text(digit)
      .font(OutwitTypography.headlineSmall)
      .foregroundStyle(OutwitColors.ink)
      .frame(maxWidth: 64, minHeight: 56)
      .background(.white, in: fieldShape)
      .overlay {
        fieldShape
          .stroke(
            isActive ? OutwitColors.action : OutwitColors.paleBorder,
            lineWidth: isActive ? 2 : 1.5
          )
      }
      .accessibilityHidden(true)
  }

  private var fieldShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: OutwitRadius.input, style: .continuous)
  }
}
