// FriendService.swift
// 好友系統：發送請求、接受/拒絕、取得好友列表與待處理請求

import Foundation
import Supabase

// MARK: - 資料模型

struct FriendRequestRecord: Decodable {
  let id: UUID
  let senderId: UUID
  let receiverId: UUID
  let status: String
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case senderId = "sender_id"
    case receiverId = "receiver_id"
    case status
    case createdAt = "created_at"
  }
}

struct FriendshipRecord: Decodable {
  let id: UUID
  let userId: UUID
  let friendId: UUID
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case friendId = "friend_id"
    case createdAt = "created_at"
  }
}

struct UserProfileRecord: Decodable {
  let userId: UUID
  let displayName: String
  let avatarUrl: String?
  let level: Int

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case displayName = "display_name"
    case avatarUrl = "avatar_url"
    case level
  }
}

// MARK: - 顯示用模型

struct FriendItem: Identifiable {
  let id: UUID
  let userId: UUID
  let displayName: String
  let avatarURL: String?
  let level: Int
}

struct FriendRequestItem: Identifiable {
  let id: UUID
  let senderId: UUID
  let displayName: String
  let avatarURL: String?
  let level: Int
  let createdAt: Date
}

struct SearchUserItem: Identifiable {
  let id: UUID
  let userId: UUID
  let displayName: String
  let avatarURL: String?
  let level: Int
}

// MARK: - FriendService

@MainActor
final class FriendService {
  private let client: SupabaseClient

  init(authService: AuthService) {
    client = authService.getClient()
  }

  // MARK: - 好友列表

  /// 取得當前使用者的好友列表（含對方 profile）
  func fetchFriends(currentUserId: UUID) async throws -> [FriendItem] {
    let friendships: [FriendshipRecord] = try await client
      .from("friendships")
      .select()
      .or("user_id.eq.\"\(currentUserId.uuidString)\",friend_id.eq.\"\(currentUserId.uuidString)\"")
      .execute()
      .value

    let friendUserIds = friendships.map { fs in
      fs.userId == currentUserId ? fs.friendId : fs.userId
    }
    guard !friendUserIds.isEmpty else { return [] }

    let profiles: [UserProfileRecord] = try await client
      .from("user_profiles")
      .select("user_id, display_name, avatar_url, level")
      .in("user_id", values: friendUserIds)
      .execute()
      .value

    let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userId, $0) })
    return friendUserIds.compactMap { fid in
      guard let p = profileMap[fid] else { return nil }
      return FriendItem(
        id: fid,
        userId: fid,
        displayName: p.displayName,
        avatarURL: p.avatarUrl,
        level: p.level
      )
    }
  }

  /// 取得已發送請求的接收者 ID 列表（含 pending、accepted、declined，避免重複發送觸發 unique 約束）
  func fetchSentRequestReceiverIds(currentUserId: UUID) async throws -> Set<UUID> {
    struct ReceiverOnly: Decodable {
      let receiverId: UUID
      enum CodingKeys: String, CodingKey { case receiverId = "receiver_id" }
    }
    let requests: [ReceiverOnly] = try await client
      .from("friend_requests")
      .select("receiver_id")
      .eq("sender_id", value: currentUserId)
      .execute()
      .value
    return Set(requests.map(\.receiverId))
  }

  // MARK: - 待處理請求（收到的）

  /// 取得收到的待處理好友請求
  func fetchPendingRequests(currentUserId: UUID) async throws -> [FriendRequestItem] {
    let requests: [FriendRequestRecord] = try await client
      .from("friend_requests")
      .select()
      .eq("receiver_id", value: currentUserId)
      .eq("status", value: "pending")
      .execute()
      .value

    guard !requests.isEmpty else { return [] }

    let senderIds = requests.map(\.senderId)
    let profiles: [UserProfileRecord] = try await client
      .from("user_profiles")
      .select("user_id, display_name, avatar_url, level")
      .in("user_id", values: senderIds)
      .execute()
      .value

    let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userId, $0) })
    return requests.compactMap { req in
      guard let p = profileMap[req.senderId] else { return nil }
      return FriendRequestItem(
        id: req.id,
        senderId: req.senderId,
        displayName: p.displayName,
        avatarURL: p.avatarUrl,
        level: p.level,
        createdAt: req.createdAt
      )
    }
  }

  // MARK: - 發送好友請求

  /// 發送好友請求給指定使用者
  func sendFriendRequest(to receiverId: UUID, currentUserId: UUID) async throws {
    struct InsertPayload: Encodable {
      let senderId: UUID
      let receiverId: UUID
      let status: String

      enum CodingKeys: String, CodingKey {
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case status
      }
    }
    let payload = InsertPayload(senderId: currentUserId, receiverId: receiverId, status: "pending")
    try await client
      .from("friend_requests")
      .insert(payload)
      .execute()
  }

  // MARK: - 接受 / 拒絕請求

  /// 接受好友請求
  func acceptFriendRequest(id: UUID) async throws {
    try await client
      .from("friend_requests")
      .update(["status": "accepted"])
      .eq("id", value: id)
      .execute()
  }

  /// 拒絕好友請求
  func declineFriendRequest(id: UUID) async throws {
    try await client
      .from("friend_requests")
      .update(["status": "declined"])
      .eq("id", value: id)
      .execute()
  }

  // MARK: - 刪除好友

  /// 刪除好友關係（雙方皆會解除）
  func deleteFriend(friendUserId: UUID, currentUserId: UUID) async throws {
    let u = min(currentUserId, friendUserId)
    let f = max(currentUserId, friendUserId)
    try await client
      .from("friendships")
      .delete()
      .eq("user_id", value: u)
      .eq("friend_id", value: f)
      .execute()
  }

  // MARK: - 搜尋使用者

  /// 依顯示名稱搜尋使用者（排除 currentUserId；excludeUserIds 於 Swift 端過濾）
  func searchUsers(query: String, currentUserId: UUID, excludeUserIds: [UUID] = []) async throws -> [SearchUserItem] {
    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

    let ilikePattern = "%\(query.trimmingCharacters(in: .whitespaces))%"
    let profiles: [UserProfileRecord] = try await client
      .from("user_profiles")
      .select("user_id, display_name, avatar_url, level")
      .ilike("display_name", pattern: ilikePattern)
      .neq("user_id", value: currentUserId)
      .limit(20)
      .execute()
      .value

    let excludeSet = Set(excludeUserIds)
    return profiles
      .filter { !excludeSet.contains($0.userId) }
      .map { p in
        SearchUserItem(
          id: p.userId,
          userId: p.userId,
          displayName: p.displayName,
          avatarURL: p.avatarUrl,
          level: p.level
        )
      }
  }
}
