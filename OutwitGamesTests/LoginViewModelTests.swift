import Testing

@testable import OutwitGames

@MainActor
struct LoginViewModelTests {
  @Test
  func phoneInputAcceptsOnlyAValidIndianMobilePrefix() {
    let context = makeContext()

    context.viewModel.updatePhone("1234567890")
    #expect(context.viewModel.phone.isEmpty)

    context.viewModel.updatePhone("98 765-43210 extra")
    #expect(context.viewModel.phone == "9876543210")
    #expect(context.viewModel.isPhoneValid)
    #expect(context.viewModel.step == .phone)
  }

  @Test
  func otpIsSentOnlyAfterTheExplicitAction() async {
    let context = makeContext()
    context.viewModel.updatePhone("9876543210")

    #expect(await context.repository.sendCalls.isEmpty)
    #expect(context.viewModel.step == .phone)

    await context.viewModel.sendOTP()

    #expect(await context.repository.sendCalls == ["9876543210"])
    #expect(context.viewModel.step == .otp)
    #expect(context.viewModel.resendSeconds == 30)
  }

  @Test
  func duplicateSendIsIgnoredWhileTheFirstRequestIsRunning() async {
    let repository = LoginRepositorySpy(sendDelay: .milliseconds(50))
    let context = makeContext(repository: repository)
    context.viewModel.updatePhone("9876543210")

    let firstRequest = Task { await context.viewModel.sendOTP() }
    while context.viewModel.operationState == .idle {
      await Task.yield()
    }
    await context.viewModel.sendOTP()
    await firstRequest.value

    #expect(await repository.sendCalls == ["9876543210"])
    #expect(context.viewModel.step == .otp)
  }

  @Test
  func cancelledSendDoesNotAdvanceTheScreen() async {
    let repository = LoginRepositorySpy(sendDelay: .seconds(1))
    let context = makeContext(repository: repository)
    context.viewModel.updatePhone("9876543210")

    let request = Task { await context.viewModel.sendOTP() }
    while context.viewModel.operationState == .idle {
      await Task.yield()
    }
    request.cancel()
    await request.value

    #expect(context.viewModel.step == .phone)
    #expect(context.viewModel.operationState == .idle)
    #expect(context.viewModel.alert == nil)
  }

  @Test
  func fourthOTPDigitRequestsAutomaticVerificationOncePerCode() async {
    let context = makeContext()
    context.viewModel.updatePhone("9876543210")
    await context.viewModel.sendOTP()

    #expect(!context.viewModel.updateOTP("246"))
    #expect(context.viewModel.updateOTP("2468"))
    #expect(!context.viewModel.updateOTP("2468"))

    await context.viewModel.verifyOTP()

    #expect(await context.repository.verifyCalls == [.init(phone: "9876543210", code: "2468")])
    #expect(context.coordinator.root == .feed)
    #expect(context.coordinator.path.isEmpty)
  }

  @Test
  func invalidValuesAreRejectedBeforeTheRepository() async {
    let context = makeContext()

    await context.viewModel.sendOTP()
    #expect(context.viewModel.alert == .error(messageKey: "invalid_phone"))
    #expect(await context.repository.sendCalls.isEmpty)

    context.viewModel.alert = nil
    context.viewModel.updatePhone("9876543210")
    await context.viewModel.sendOTP()
    _ = context.viewModel.updateOTP("12")
    await context.viewModel.verifyOTP()

    #expect(context.viewModel.alert == .error(messageKey: "invalid_otp"))
    #expect(await context.repository.verifyCalls.isEmpty)
  }

  @Test
  func phoneTakenOffersExistingAccountThenCompletesLogin() async {
    let repository = LoginRepositorySpy(
      verifyResult: .failure(.phoneAlreadyRegistered)
    )
    let context = makeContext(repository: repository)
    context.viewModel.updatePhone("9876543210")
    await context.viewModel.sendOTP()
    _ = context.viewModel.updateOTP("2468")

    await context.viewModel.verifyOTP()

    #expect(context.viewModel.alert == .phoneAlreadyRegistered)
    #expect(context.coordinator.root == .login)

    context.viewModel.alert = nil
    await context.viewModel.loginToExistingAccount()

    #expect(await repository.existingAccountCalls == [.init(phone: "9876543210", code: "2468")])
    #expect(context.coordinator.root == .feed)
  }

  @Test
  func choosingAnotherNumberReturnsToThePhoneStep() async {
    let context = makeContext()
    context.viewModel.updatePhone("9876543210")
    await context.viewModel.sendOTP()
    _ = context.viewModel.updateOTP("2468")

    context.viewModel.changePhone()

    #expect(context.viewModel.step == .phone)
    #expect(context.viewModel.phone == "9876543210")
    #expect(context.viewModel.otp.isEmpty)
    #expect(context.viewModel.resendSeconds == 0)
  }

  @Test
  func resendCooldownExpiresAndAllowsAnotherRequest() async throws {
    let context = makeContext(cooldown: 2, tick: .milliseconds(1))
    context.viewModel.updatePhone("9876543210")
    await context.viewModel.sendOTP()

    for _ in 0..<100 where context.viewModel.resendSeconds > 0 {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(context.viewModel.resendSeconds == 0)

    await context.viewModel.resendOTP()
    #expect(await context.repository.sendCalls.count == 2)
  }

  private func makeContext(
    repository: LoginRepositorySpy = LoginRepositorySpy(),
    cooldown: Int = 30,
    tick: Duration = .seconds(1)
  ) -> LoginTestContext {
    let coordinator = AppCoordinator(root: .login)
    return LoginTestContext(
      viewModel: LoginViewModel(
        authRepository: repository,
        coordinator: coordinator,
        resendCooldownSeconds: cooldown,
        resendTickDuration: tick
      ),
      repository: repository,
      coordinator: coordinator
    )
  }
}

private struct LoginTestContext {
  let viewModel: LoginViewModel
  let repository: LoginRepositorySpy
  let coordinator: AppCoordinator
}

private nonisolated struct LoginCall: Equatable, Sendable {
  let phone: String
  let code: String
}

private enum LoginRepositoryTestError: Error, Sendable {
  case phoneAlreadyRegistered
}

private actor LoginRepositorySpy: AuthRepository {
  private let verifyResult: Result<AuthUser, LoginRepositoryTestError>
  private let sendDelay: Duration?
  private(set) var sendCalls: [String] = []
  private(set) var verifyCalls: [LoginCall] = []
  private(set) var existingAccountCalls: [LoginCall] = []

  init(
    verifyResult: Result<AuthUser, LoginRepositoryTestError>? = nil,
    sendDelay: Duration? = nil
  ) {
    self.verifyResult = verifyResult ?? .success(Self.registeredUser)
    self.sendDelay = sendDelay
  }

  func sendOTP(to nationalPhoneNumber: String) async throws {
    sendCalls.append(nationalPhoneNumber)
    if let sendDelay {
      try await Task.sleep(for: sendDelay)
    }
  }

  func verifyOTP(phone: String, code: String) async throws -> AuthUser {
    verifyCalls.append(LoginCall(phone: phone, code: code))
    do {
      return try verifyResult.get()
    } catch LoginRepositoryTestError.phoneAlreadyRegistered {
      throw AuthenticationError.phoneAlreadyRegistered
    }
  }

  func loginToExistingAccount(phone: String, code: String) async throws -> AuthUser {
    existingAccountCalls.append(LoginCall(phone: phone, code: code))
    return Self.registeredUser
  }

  private static let registeredUser = AuthUser(
    id: 91,
    kind: "registered",
    username: "player",
    phone: "+919876543210",
    externalID: "external-91"
  )
}
