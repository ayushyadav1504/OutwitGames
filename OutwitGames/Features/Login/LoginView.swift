import SwiftUI

struct LoginView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var operationTask: Task<Void, Never>?
  @State private var viewModel: LoginViewModel
  @FocusState private var isPhoneFocused: Bool
  @FocusState private var isOTPFocused: Bool

  init(authRepository: any AuthRepository, coordinator: AppCoordinator) {
    _viewModel = State(
      initialValue: LoginViewModel(
        authRepository: authRepository,
        coordinator: coordinator
      )
    )
  }

  var body: some View {
    @Bindable var viewModel = viewModel

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(titleKey)
          .font(OutwitTypography.headlineLarge)
          .foregroundStyle(OutwitColors.ink)
          .accessibilityIdentifier("login-heading")

        description
          .padding(.top, OutwitSpacing.x2)

        Group {
          switch viewModel.step {
          case .phone:
            phoneStep
          case .otp:
            otpStep
          }
        }
        .padding(.top, OutwitSpacing.x6)
      }
      .frame(maxWidth: 560, alignment: .leading)
      .padding(.horizontal, OutwitSpacing.pageGutter)
      .padding(.top, OutwitSpacing.x8)
      .padding(.bottom, OutwitSpacing.x8)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom) {
      primaryAction
    }
    .background(OutwitColors.softWhite.ignoresSafeArea())
    .navigationTitle("screen.login.title")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.white, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .alert(item: $viewModel.alert, content: alert)
    .task {
      isPhoneFocused = true
    }
    .onChange(of: viewModel.step) { _, step in
      if reduceMotion {
        focus(step)
      } else {
        withAnimation(.easeInOut(duration: 0.2)) {
          focus(step)
        }
      }
    }
    .onDisappear {
      operationTask?.cancel()
      operationTask = nil
      viewModel.cancel()
    }
  }

  private var titleKey: LocalizedStringKey {
    switch viewModel.step {
    case .phone:
      "login.phone.title"
    case .otp:
      "login.otp.title"
    }
  }

  @ViewBuilder
  private var description: some View {
    switch viewModel.step {
    case .phone:
      Text("login.phone.description")
        .font(OutwitTypography.body)
        .foregroundStyle(OutwitColors.ink)
    case .otp:
      HStack(alignment: .firstTextBaseline, spacing: OutwitSpacing.x2) {
        VStack(alignment: .leading, spacing: 2) {
          Text("login.otp.sent")
            .font(OutwitTypography.body)
            .foregroundStyle(OutwitColors.mutedInk)
          Text(verbatim: "+91 \(viewModel.phone)")
            .font(OutwitTypography.bodyEmphasized)
            .foregroundStyle(OutwitColors.ink)
        }

        Button {
          viewModel.changePhone()
        } label: {
          Image(systemName: "pencil.circle.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(OutwitColors.action)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("login.change_number")
      }
    }
  }

  private var phoneStep: some View {
    VStack(alignment: .leading, spacing: OutwitSpacing.x3) {
      PhoneNumberField(
        phone: phoneBinding,
        isFocused: $isPhoneFocused
      )

      Label("login.phone.safety", systemImage: "lock.shield")
        .font(OutwitTypography.bodySmall)
        .foregroundStyle(OutwitColors.mutedInk)
    }
  }

  private var otpStep: some View {
    VStack(spacing: OutwitSpacing.x3) {
      OTPCodeField(
        code: otpBinding,
        isFocused: $isOTPFocused
      )
      .disabled(viewModel.isBusy)

      if viewModel.resendSeconds > 0 {
        HStack(spacing: 4) {
          Text("login.otp.resend_in")
          Text(verbatim: "\(viewModel.resendSeconds)s")
        }
        .font(OutwitTypography.bodySmall)
        .foregroundStyle(OutwitColors.mutedInk)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
      } else {
        Button("login.otp.resend") {
          runOperation { await viewModel.resendOTP() }
        }
        .font(OutwitTypography.label)
        .foregroundStyle(OutwitColors.action)
        .frame(maxWidth: .infinity, minHeight: 48)
        .disabled(viewModel.isBusy)
        .accessibilityIdentifier("login-resend-otp")
      }
    }
  }

  private var primaryAction: some View {
    Button {
      runOperation { await viewModel.performPrimaryAction() }
    } label: {
      if viewModel.isBusy {
        ProgressView()
          .tint(.white)
          .accessibilityLabel("common.loading")
      } else {
        Text(viewModel.step == .phone ? "common.continue" : "login.verify")
      }
    }
    .buttonStyle(.outwitPrimary)
    .disabled(viewModel.isBusy)
    .accessibilityIdentifier("login-primary-action")
    .frame(maxWidth: 560)
    .padding(.horizontal, OutwitSpacing.pageGutter)
    .padding(.vertical, OutwitSpacing.x3)
    .frame(maxWidth: .infinity)
    .background(OutwitColors.softWhite.opacity(0.97))
  }

  private func updateOTP(_ value: String) {
    if viewModel.updateOTP(value) {
      runOperation { await viewModel.verifyOTP() }
    }
  }

  private var phoneBinding: Binding<String> {
    Binding(
      get: { viewModel.phone },
      set: { viewModel.updatePhone($0) }
    )
  }

  private var otpBinding: Binding<String> {
    Binding(
      get: { viewModel.otp },
      set: { value in updateOTP(value) }
    )
  }

  private func focus(_ step: LoginStep) {
    isPhoneFocused = step == .phone
    isOTPFocused = step == .otp
  }

  private func runOperation(_ operation: @escaping @MainActor () async -> Void) {
    guard operationTask == nil else { return }
    operationTask = Task {
      await operation()
      operationTask = nil
    }
  }

  private func alert(_ alert: LoginAlert) -> Alert {
    switch alert {
    case .error(let messageKey):
      Alert(
        title: Text("login.error.title"),
        message: Text(LocalizedStringKey(messageKey)),
        dismissButton: .default(Text("common.ok"))
      )
    case .phoneAlreadyRegistered:
      Alert(
        title: Text("login.phone_taken.title"),
        message: Text("login.phone_taken.message"),
        primaryButton: .default(Text("common.continue")) {
          runOperation { await viewModel.loginToExistingAccount() }
        },
        secondaryButton: .cancel(Text("login.use_new_number")) {
          viewModel.changePhone()
        }
      )
    }
  }
}

#Preview {
  NavigationStack {
    LoginView(
      authRepository: PreviewAuthRepository(),
      coordinator: AppCoordinator(root: .login)
    )
  }
}

private nonisolated struct PreviewAuthRepository: AuthRepository {
  func sendOTP(to nationalPhoneNumber: String) async throws {}

  func verifyOTP(phone: String, code: String) async throws -> AuthUser {
    AuthUser(id: 1, kind: "registered", username: "player", phone: phone, externalID: "")
  }

  func loginToExistingAccount(phone: String, code: String) async throws -> AuthUser {
    try await verifyOTP(phone: phone, code: code)
  }

  func signOut() async throws {}
  func deleteAccount() async throws {}
}
