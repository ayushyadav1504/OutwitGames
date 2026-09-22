import Foundation

nonisolated struct ProfileIdentity: Equatable, Sendable {
  let name: String
  let phone: String
  let isRegistered: Bool
}

nonisolated enum ProfileScreenState: Equatable, Sendable {
  case idle
  case loading
  case loaded(ProfileIdentity)
  case failed(messageKey: String)
}

nonisolated enum ProfileOperationState: Equatable, Sendable {
  case idle
  case signingOut
  case deletingAccount
}
