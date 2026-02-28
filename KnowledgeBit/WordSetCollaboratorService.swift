// WordSetCollaboratorService.swift
// 單字集共編成員：從 Supabase 載入 / 更新 word_set_collaborators

import Foundation
import Supabase

struct WordSetCollaborator: Identifiable, Equatable {
  let id: UUID
  let userId: UUID
  let displayName: String
  let avatarURL: String?
}

private struct WordSetCollaboratorRow: Decodable {
  let wordSetId: UUID
  let userId: UUID

  enum CodingKeys: String, CodingKey {
    case wordSetId = "word_set_id"
    case userId = "user_id"
  }
}

@MainActor
final class WordSetCollaboratorService {
  private let client: SupabaseClient
  private let userId: UUID

  init(authService: AuthService, userId: UUID) {
    self.client = authService.getClient()
    self.userId = userId
  }

  /// 取得某單字集的共編成員（以 user_profiles 為準），改走 RPC 避開 RLS 遞迴
  func fetchCollaborators(wordSetId: UUID) async throws -> [WordSetCollaborator] {
    let rows: [WordSetCollaboratorRow] = try await client
      .rpc("get_word_set_collaborators", params: ["p_word_set_id": wordSetId.uuidString])
      .execute()
      .value

    guard !rows.isEmpty else { return [] }

    let userIds = rows.map(\.userId)

    // 這裡重用 FriendService 裡的 UserProfileRecord 型別
    let profiles: [UserProfileRecord] = try await client
      .from("user_profiles")
      .select("user_id, display_name, avatar_url, level")
      .in("user_id", values: userIds)
      .execute()
      .value

    let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userId, $0) })

    return rows.compactMap { row in
      guard let p = profileMap[row.userId] else { return nil }
      return WordSetCollaborator(
        id: row.userId,
        userId: row.userId,
        displayName: p.displayName,
        avatarURL: p.avatarUrl
      )
    }
  }

  /// 覆寫某單字集的共編名單（僅擁有者可呼叫，改走 RPC 避開 RLS 遞迴）
  func setCollaborators(wordSetId: UUID, collaboratorIds: [UUID]) async throws {
    let idsJson = "[" + collaboratorIds.map { "\"\($0.uuidString)\"" }.joined(separator: ",") + "]"
    _ = try await client
      .rpc("set_word_set_collaborators", params: [
        "p_word_set_id": wordSetId.uuidString,
        "p_collaborator_ids": idsJson
      ])
      .execute()
  }
}

