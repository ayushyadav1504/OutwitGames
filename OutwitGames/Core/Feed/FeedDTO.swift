import Foundation

nonisolated struct FeedDTO: Decodable, Sendable {
  let feed: [FeedChallengeDTO]
  let milestone: MilestoneProgressDTO?
  let pagination: FeedPaginationDTO?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    feed = try container.decodeIfPresent([FeedChallengeDTO].self, forKey: .feed) ?? []
    milestone = try container.decodeIfPresent(MilestoneProgressDTO.self, forKey: .milestone)
    pagination = try container.decodeIfPresent(FeedPaginationDTO.self, forKey: .pagination)
  }

  func toDomain() throws -> FeedPage {
    let nextCursor: String?
    if pagination?.hasMore == true {
      guard let cursor = pagination?.nextCursor?.trimmingCharacters(in: .whitespacesAndNewlines),
        !cursor.isEmpty
      else {
        throw AppError.parsing
      }
      nextCursor = cursor
    } else {
      nextCursor = nil
    }

    return FeedPage(
      challenges: feed.map { $0.toDomain() },
      milestone: milestone?.toDomain(),
      nextCursor: nextCursor
    )
  }

  private enum CodingKeys: String, CodingKey {
    case feed
    case milestone
    case pagination
  }
}

nonisolated struct FeedChallengeDTO: Decodable, Sendable {
  let id: Int
  let gameKey: String
  let title: String
  let objective: [String: JSONValue]
  let difficulty: Double
  let rewardCoins: Int
  let bundle: FeedGameBundleDTO?
  let media: [ChallengeMediaDTO]

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
    gameKey = try container.decodeIfPresent(String.self, forKey: .gameKey) ?? ""
    title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    objective = try container.decodeIfPresent([String: JSONValue].self, forKey: .objective) ?? [:]
    difficulty = try container.decodeIfPresent(Double.self, forKey: .difficulty) ?? 0
    rewardCoins = try container.decodeIfPresent(Int.self, forKey: .rewardCoins) ?? 0
    bundle = try container.decodeIfPresent(FeedGameBundleDTO.self, forKey: .bundle)
    media = try container.decodeIfPresent([ChallengeMediaDTO].self, forKey: .media) ?? []
  }

  func toDomain() -> FeedChallenge {
    FeedChallenge(
      id: id,
      gameKey: gameKey,
      title: title,
      objective: ChallengeObjective(raw: objective),
      difficulty: difficulty,
      rewardCoins: rewardCoins,
      bundle: bundle?.toDomain(),
      media: media.map { $0.toDomain() }
    )
  }

  private enum CodingKeys: String, CodingKey {
    case id = "challenge_id"
    case gameKey = "game_key"
    case title
    case objective
    case difficulty
    case rewardCoins = "reward_coins"
    case bundle
    case media
  }
}

nonisolated struct FeedGameBundleDTO: Decodable, Sendable {
  let version: String
  let url: String
  let entry: String

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decodeIfPresent(String.self, forKey: .version) ?? ""
    url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
    entry = try container.decodeIfPresent(String.self, forKey: .entry) ?? "index.html"
  }

  func toDomain() -> FeedGameBundle {
    FeedGameBundle(version: version, url: url, entry: entry)
  }

  private enum CodingKeys: String, CodingKey {
    case version
    case url
    case entry
  }
}

nonisolated struct ChallengeMediaDTO: Decodable, Sendable {
  let tag: String
  let type: String
  let url: String
  let webPURL: String
  let thumbnailURL: String

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
    type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
    url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
    webPURL = try container.decodeIfPresent(String.self, forKey: .webPURL) ?? ""
    thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) ?? ""
  }

  func toDomain() -> ChallengeMedia {
    ChallengeMedia(
      tag: tag,
      type: type,
      url: url,
      webPURL: webPURL,
      thumbnailURL: thumbnailURL
    )
  }

  private enum CodingKeys: String, CodingKey {
    case tag
    case type
    case url
    case webPURL = "webp_url"
    case thumbnailURL = "thumbnail_url"
  }
}

nonisolated struct MilestoneProgressDTO: Decodable, Sendable {
  let lifetimeCoins: Int
  let nextMilestone: MilestoneTierDTO?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    lifetimeCoins = try container.decodeIfPresent(Int.self, forKey: .lifetimeCoins) ?? 0
    nextMilestone = try container.decodeIfPresent(MilestoneTierDTO.self, forKey: .nextMilestone)
  }

  func toDomain() -> MilestoneProgress {
    MilestoneProgress(lifetimeCoins: lifetimeCoins, next: nextMilestone?.toDomain())
  }

  private enum CodingKeys: String, CodingKey {
    case lifetimeCoins = "lifetime_coins"
    case nextMilestone = "next_milestone"
  }
}

nonisolated struct MilestoneTierDTO: Decodable, Sendable {
  let label: String
  let threshold: Int
  let rewardCoins: Int
  let remaining: Int

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
    threshold = try container.decodeIfPresent(Int.self, forKey: .threshold) ?? 0
    rewardCoins = try container.decodeIfPresent(Int.self, forKey: .rewardCoins) ?? 0
    remaining = try container.decodeIfPresent(Int.self, forKey: .remaining) ?? 0
  }

  func toDomain() -> MilestoneTier {
    MilestoneTier(
      label: label,
      threshold: threshold,
      rewardCoins: rewardCoins,
      remaining: remaining
    )
  }

  private enum CodingKeys: String, CodingKey {
    case label
    case threshold
    case rewardCoins = "reward_coins"
    case remaining
  }
}

nonisolated struct FeedPaginationDTO: Decodable, Sendable {
  let hasMore: Bool
  let nextCursor: String?

  enum CodingKeys: String, CodingKey {
    case hasMore = "has_more"
    case nextCursor = "next_cursor"
  }
}
