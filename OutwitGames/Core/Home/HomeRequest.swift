import Foundation

nonisolated struct HomeDTO: Decodable, Sendable {
  let wallet: WalletDTO

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    wallet = try container.decodeIfPresent(WalletDTO.self, forKey: .wallet) ?? WalletDTO()
  }

  private enum CodingKeys: String, CodingKey {
    case wallet
  }
}

nonisolated struct WalletDTO: Decodable, Sendable {
  let coins: Int
  let elixir: Int

  init(coins: Int = 0, elixir: Int = 0) {
    self.coins = coins
    self.elixir = elixir
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    coins = try container.decodeIfPresent(Int.self, forKey: .coins) ?? 0
    elixir = try container.decodeIfPresent(Int.self, forKey: .elixir) ?? 0
  }

  func toDomain() -> WalletBalance {
    WalletBalance(coins: coins, elixir: elixir)
  }

  private enum CodingKeys: String, CodingKey {
    case coins
    case elixir
  }
}

enum HomeRequest {
  static func make() -> APIRequest<WalletBalance> {
    APIRequest(
      path: "/home",
      decoding: HomeDTO.self,
      map: { $0.wallet.toDomain() }
    )
  }
}
