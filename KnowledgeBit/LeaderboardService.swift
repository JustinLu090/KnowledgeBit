// LeaderboardService.swift
// 好友排行榜：查詢好友 + 自己的本週 EXP 並排名

import Foundation
import Supabase

// MARK: - Model

struct LeaderboardEntry: Identifiable {
  let id: UUID
  let userId: UUID
  let displayName: String
  let avatarURL: String?
  let level: Int
  let weeklyExp: Int
  var rank: Int
  let isCurrentUser: Bool
}

// MARK: - Service

final class LeaderboardService {
  private let client: SupabaseClient

  init(authService: AuthService) {
    client = authService.getClient()
  }

  /// 取得好友 + 自己的本週排行（依 weekly_exp 降序）
  func fetchLeaderboard(currentUserId: UUID, friends: [FriendItem]) async throws -> [LeaderboardEntry] {
    let allIds = ([currentUserId] + friends.map(\.userId))

    struct ProfileRow: Decodable {
      let userId: UUID
      let displayName: String
      let avatarUrl: String?
      let level: Int
      let weeklyExp: Int

      enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case level
        case weeklyExp = "weekly_exp"
      }
    }

    let rows: [ProfileRow] = try await client
      .from("user_profiles")
      .select("user_id, display_name, avatar_url, level, weekly_exp")
      .in("user_id", values: allIds)
      .execute()
      .value

    var entries: [LeaderboardEntry] = rows.map { row in
      LeaderboardEntry(
        id: row.userId,
        userId: row.userId,
        displayName: row.displayName,
        avatarURL: row.avatarUrl,
        level: row.level,
        weeklyExp: row.weeklyExp,
        rank: 0,
        isCurrentUser: row.userId == currentUserId
      )
    }

    // Sort by weeklyExp descending, then level as tiebreaker
    entries.sort {
      if $0.weeklyExp != $1.weeklyExp { return $0.weeklyExp > $1.weeklyExp }
      return $0.level > $1.level
    }

    for i in entries.indices { entries[i].rank = i + 1 }
    return entries
  }
}
