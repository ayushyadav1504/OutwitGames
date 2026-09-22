import Foundation

nonisolated enum DeleteAccountRequest {
  static func make() -> APIRequest<Void> {
    APIRequest(
      path: "/account",
      method: .delete,
      decoding: DeleteAccountResponse.self,
      map: { response in
        guard response.status == "deletion_scheduled" else {
          throw AppError.parsing
        }
      }
    )
  }
}

private nonisolated struct DeleteAccountResponse: Decodable, Sendable {
  let status: String
}
