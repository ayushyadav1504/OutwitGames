import Foundation

nonisolated struct FeedPage: Equatable, Sendable {
  let challenges: [FeedChallenge]
  let milestone: MilestoneProgress?
  let nextCursor: String?

  var hasMore: Bool { nextCursor != nil }
}

nonisolated struct FeedChallenge: Codable, Identifiable, Equatable, Hashable, Sendable {
  let id: Int
  let gameKey: String
  let title: String
  let objective: ChallengeObjective
  let difficulty: Double
  let rewardCoins: Int
  let bundle: FeedGameBundle?
  let media: [ChallengeMedia]

  var isPlayable: Bool {
    guard let bundle else { return false }
    return !bundle.entryURLString.isEmpty
  }

  var backgroundVideoURL: URL? {
    preferredMediaURL(
      preferred: { $0.isVideo && $0.isFeedBackground },
      fallback: \ChallengeMedia.isVideo,
      value: \ChallengeMedia.url
    )
  }

  var backgroundAudioURL: URL? {
    preferredMediaURL(
      preferred: { $0.isAudio && $0.isBackgroundMusic },
      fallback: \ChallengeMedia.isAudio,
      value: \ChallengeMedia.url
    )
  }

  var heroImageURL: URL? {
    let candidates = [
      media.first { $0.isImage && $0.normalizedTag == "hero" }?.displayURL,
      media.first { $0.isVideo }?.thumbnailURL,
      media.first { $0.isImage }?.displayURL,
    ]
    return candidates.compactMap(Self.secureMediaURL).first
  }

  private func preferredMediaURL(
    preferred: (ChallengeMedia) -> Bool,
    fallback: (ChallengeMedia) -> Bool,
    value: KeyPath<ChallengeMedia, String>
  ) -> URL? {
    let candidates = media.filter(preferred) + media.filter(fallback)
    return candidates.lazy.compactMap { Self.secureMediaURL($0[keyPath: value]) }.first
  }

  private static func secureMediaURL(_ value: String?) -> URL? {
    guard
      let value,
      let url = URL(string: value),
      url.scheme?.lowercased() == "https",
      url.host?.isEmpty == false,
      url.user == nil,
      url.password == nil
    else {
      return nil
    }
    return url
  }
}

nonisolated struct ChallengeObjective: Codable, Equatable, Hashable, Sendable {
  let raw: [String: JSONValue]

  var type: String { raw["type"]?.stringValue ?? "" }
  var metric: String? { raw["metric"]?.stringValue }
  var target: Int? { raw["target"]?.intValue }
  var maximum: Int? { raw["max"]?.intValue }
  var maximumMilliseconds: Int? { raw["max_ms"]?.intValue }
  var minimumMilliseconds: Int? { raw["min_ms"]?.intValue }
}

nonisolated struct ChallengeMedia: Codable, Equatable, Hashable, Sendable {
  let tag: String
  let type: String
  let url: String
  let webPURL: String
  let thumbnailURL: String

  var displayURL: String { webPURL.isEmpty ? url : webPURL }
  var normalizedTag: String { tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

  var isVideo: Bool {
    normalizedType == "video"
      || normalizedType == "mp4"
      || normalizedType == "hls"
      || normalizedType.hasPrefix("video/")
      || hasExtension(["mp4", "m3u8", "mov", "webm"])
  }

  var isAudio: Bool {
    normalizedType == "audio"
      || normalizedType == "mp3"
      || normalizedType.hasPrefix("audio/")
      || hasExtension(["aac", "m4a", "mp3", "ogg", "wav"])
  }

  var isImage: Bool { !isVideo && !isAudio }

  var isFeedBackground: Bool {
    ["hero", "background", "background_video", "feed_background", "feed_video"]
      .contains(normalizedTag)
  }

  var isBackgroundMusic: Bool {
    ["audio", "background_audio", "background_music", "bgm", "music"]
      .contains(normalizedTag)
  }

  private var normalizedType: String {
    type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func hasExtension(_ extensions: Set<String>) -> Bool {
    guard let pathExtension = URL(string: url)?.pathExtension.lowercased() else { return false }
    return extensions.contains(pathExtension)
  }
}

nonisolated struct FeedGameBundle: Codable, Equatable, Hashable, Sendable {
  let version: String
  let url: String
  let entry: String

  var entryURLString: String {
    guard !url.isEmpty, !entry.isEmpty, let baseURL = URL(string: url) else { return "" }
    return baseURL.appending(path: entry).absoluteString
  }
}

nonisolated struct MilestoneProgress: Equatable, Sendable {
  let lifetimeCoins: Int
  let next: MilestoneTier?
}

nonisolated struct MilestoneTier: Equatable, Sendable {
  let label: String
  let threshold: Int
  let rewardCoins: Int
  let remaining: Int
}
