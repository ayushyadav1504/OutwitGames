import Foundation
import Observation

enum LoginStep: Equatable, Sendable {
  case phone
  case otp
}

enum LoginOperationState: Equatable, Sendable {
  case idle
  case sendingOTP
  case verifyingOTP
  case signingIntoExistingAccount
}

enum LoginAlert: Equatable, Identifiable, Sendable {
  case error(messageKey: String)
  case phoneAlreadyRegistered

  var id: String {
    switch self {
    case .error(let messageKey):
      "error-\(messageKey)"
    case .phoneAlreadyRegistered:
      "phone-already-registered"
    }
  }
}

@MainActor
@Observable
final class LoginViewModel {
  static let phoneLength = 10
  static let otpLength = 4

  private let authRepository: any AuthRepository
  private let coordinator: AppCoordinator
  private let resendCooldownSeconds: Int
  private let resendTickDuration: Duration

  private var resendTask: Task<Void, Never>?
  private var lastAutoVerifiedCode: String?

  private(set) var step = LoginStep.phone
  private(set) var phone = ""
  private(set) var otp = ""
  private(set) var operationState = LoginOperationState.idle
  private(set) var resendSeconds = 0
  var alert: LoginAlert?

  init(
    authRepository: any AuthRepository,
    coordinator: AppCoordinator,
    resendCooldownSeconds: Int = 30,
    resendTickDuration: Duration = .seconds(1)
  ) {
    self.authRepository = authRepository
    self.coordinator = coordinator
    self.resendCooldownSeconds = resendCooldownSeconds
    self.resendTickDuration = resendTickDuration
  }

  var isBusy: Bool {
    operationState != .idle
  }

  var isPhoneValid: Bool {
    phone.count == Self.phoneLength && phone.first.map(Self.validFirstDigits.contains) == true
  }

  var isOTPValid: Bool {
    otp.count == Self.otpLength && otp.allSatisfy(\.isNumber)
  }

  func updatePhone(_ value: String) {
    guard !isBusy else { return }
    let digits = String(value.filter(Self.asciiDigits.contains).prefix(Self.phoneLength))
    guard digits.isEmpty || digits.first.map(Self.validFirstDigits.contains) == true else {
      return
    }
    phone = digits
  }

  @discardableResult
  func updateOTP(_ value: String) -> Bool {
    guard !isBusy else { return false }
    let digits = String(value.filter(Self.asciiDigits.contains).prefix(Self.otpLength))
    otp = digits

    guard isOTPValid else {
      lastAutoVerifiedCode = nil
      return false
    }
    guard lastAutoVerifiedCode != digits else { return false }
    lastAutoVerifiedCode = digits
    return true
  }

  func performPrimaryAction() async {
    switch step {
    case .phone:
      await sendOTP()
    case .otp:
      await verifyOTP()
    }
  }

  func sendOTP() async {
    guard operationState == .idle else { return }
    guard isPhoneValid else {
      alert = .error(messageKey: "invalid_phone")
      return
    }

    operationState = .sendingOTP
    defer { operationState = .idle }

    do {
      try await authRepository.sendOTP(to: phone)
      try Task.checkCancellation()
      otp = ""
      lastAutoVerifiedCode = nil
      step = .otp
      startResendCountdown()
    } catch is CancellationError {
      return
    } catch let error as AppError {
      alert = .error(messageKey: error.messageKey)
    } catch {
      alert = .error(messageKey: "something_wrong")
    }
  }

  func resendOTP() async {
    guard operationState == .idle, resendSeconds == 0 else { return }

    operationState = .sendingOTP
    defer { operationState = .idle }

    do {
      try await authRepository.sendOTP(to: phone)
      try Task.checkCancellation()
      startResendCountdown()
    } catch is CancellationError {
      return
    } catch let error as AppError {
      alert = .error(messageKey: error.messageKey)
    } catch {
      alert = .error(messageKey: "something_wrong")
    }
  }

  func verifyOTP() async {
    guard operationState == .idle else { return }
    guard isOTPValid else {
      alert = .error(messageKey: "invalid_otp")
      return
    }

    operationState = .verifyingOTP
    defer { operationState = .idle }

    do {
      _ = try await authRepository.verifyOTP(phone: phone, code: otp)
      try Task.checkCancellation()
      completeLogin()
    } catch is CancellationError {
      return
    } catch AuthenticationError.phoneAlreadyRegistered {
      alert = .phoneAlreadyRegistered
    } catch let error as AppError {
      alert = .error(messageKey: error.messageKey)
    } catch {
      alert = .error(messageKey: "something_wrong")
    }
  }

  func loginToExistingAccount() async {
    guard operationState == .idle else { return }

    operationState = .signingIntoExistingAccount
    defer { operationState = .idle }

    do {
      _ = try await authRepository.loginToExistingAccount(phone: phone, code: otp)
      try Task.checkCancellation()
      completeLogin()
    } catch is CancellationError {
      return
    } catch let error as AppError {
      alert = .error(messageKey: error.messageKey)
    } catch {
      alert = .error(messageKey: "something_wrong")
    }
  }

  func changePhone() {
    guard !isBusy else { return }
    resendTask?.cancel()
    resendTask = nil
    resendSeconds = 0
    otp = ""
    lastAutoVerifiedCode = nil
    alert = nil
    step = .phone
  }

  func cancel() {
    resendTask?.cancel()
    resendTask = nil
  }

  private func startResendCountdown() {
    resendTask?.cancel()
    resendSeconds = resendCooldownSeconds
    let tickDuration = resendTickDuration

    resendTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: tickDuration)
        } catch {
          return
        }

        guard let seconds = self?.resendSeconds else { return }
        if seconds <= 1 {
          self?.resendSeconds = 0
          return
        }
        self?.resendSeconds = seconds - 1
      }
    }
  }

  private func completeLogin() {
    resendTask?.cancel()
    resendTask = nil
    resendSeconds = 0
    coordinator.restartAfterLogin()
  }

  private static let validFirstDigits = "56789"
  private static let asciiDigits = "0123456789"
}
