import Foundation

enum FeedRequest {
  static func make(count: Int = 5, cursor: String? = nil) -> APIRequest<FeedPage> {
    var queryItems = [APIQueryItem(name: "count", value: String(count))]
    if let cursor, !cursor.isEmpty {
      queryItems.append(APIQueryItem(name: "cursor", value: cursor))
    }

    return APIRequest(
      path: "/feed",
      queryItems: queryItems,
      decoding: FeedDTO.self,
      map: { try $0.toDomain() }
    )
  }
}
