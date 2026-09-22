import Foundation

nonisolated enum RewardsCatalogRequest {
  static func make(geo: String? = nil) -> APIRequest<RewardCatalog> {
    APIRequest(
      path: "/rewards",
      queryItems: geo.map { [APIQueryItem(name: "geo", value: $0)] } ?? [],
      decoding: RewardCatalogDTO.self,
      map: { $0.domainModel() }
    )
  }
}

nonisolated enum RewardRedemptionsRequest {
  static func make() -> APIRequest<[RewardRedemption]> {
    APIRequest(
      path: "/rewards/redemptions",
      decoding: RewardRedemptionsDTO.self,
      map: { $0.redemptions.map { $0.domainModel() } }
    )
  }
}

nonisolated enum RedeemRewardRequest {
  static func make(sku: String, geo: String? = nil) throws -> APIRequest<RewardRedemption> {
    try APIRequest(
      path: "/rewards/redeem",
      method: .post,
      jsonBody: Body(sku: sku, geo: geo),
      decoding: RewardRedemptionResponseDTO.self,
      map: { $0.redemption.domainModel() }
    )
  }

  private struct Body: Encodable, Sendable {
    let sku: String
    let geo: String?
  }
}

nonisolated enum ReferralInfoRequest {
  static func make() -> APIRequest<ReferralInfo> {
    APIRequest(
      path: "/referrals",
      decoding: ReferralInfoDTO.self,
      map: { $0.domainModel }
    )
  }
}
