// WordSetInvitationService.swift
// 單字集邀請：發送邀請、取得待確認列表、接受/拒絕

import Foundation
import Supabase

struct WordSetInvitationItem: Identifiable, Equatable {
  let id: UUID
  let wordSetId: UUID
  let wordSetTitle: String
  let inviterId: UUID
  let inviterDisplayName: String
  let createdAt: Date
}

private struct PendingInvitationRow: Decodable {
  let id: UUID
  let word_set_id: UUID
  let word_set_title: String?
  let inviter_id: UUID
  let inviter_display_name: String?
  let created_at: Date
}

@MainActor
final class WordSetInvitationService {
  private let client: SupabaseClient
  private let userId: UUID

  init(authService: AuthService, userId: UUID) {
    self.client = authService.getClient()
    self.userId = userId
  }

  /// 我收到的待處理單字集邀請
  func fetchMyPendingInvitations() async throws -> [WordSetInvitationItem] {
    let rows: [PendingInvitationRow] = try await client
      .rpc("get_my_pending_word_set_invitations")
      .execute()
      .value

    return rows.map { row in
      WordSetInvitationItem(
        id: row.id,
        wordSetId: row.word_set_id,
        wordSetTitle: row.word_set_title ?? "單字集",
        inviterId: row.inviter_id,
        inviterDisplayName: row.inviter_display_name ?? "使用者",
        createdAt: row.created_at
      )
    }
  }

  /// 接受邀請（加入共編後該單字集會出現在「單字集」列表）
  func acceptInvitation(id: UUID) async throws {
    _ = try await client
      .rpc("respond_word_set_invitation", params: [
        "p_invitation_id": id.uuidString,
        "p_accept": "true"
      ])
      .execute()
  }

  /// 拒絕邀請
  func declineInvitation(id: UUID) async throws {
    _ = try await client
      .rpc("respond_word_set_invitation", params: [
        "p_invitation_id": id.uuidString,
        "p_accept": "false"
      ])
      .execute()
  }

  /// 發送邀請（僅單字集擁有者；可多次呼叫同一人會更新 updated_at）
  func sendInvitation(wordSetId: UUID, inviteeId: UUID) async throws {
    _ = try await client
      .rpc("create_word_set_invitation", params: [
        "p_word_set_id": wordSetId.uuidString,
        "p_invitee_id": inviteeId.uuidString
      ])
      .execute()
  }

  /// 某單字集目前待確認的邀請（擁有者用）
  struct PendingInvitee: Identifiable {
    var id: UUID { invitationId }
    let invitationId: UUID
    let inviteeId: UUID
    let inviteeDisplayName: String
    let createdAt: Date
  }

  private struct PendingInviteeRow: Decodable {
    let invitation_id: UUID
    let invitee_id: UUID
    let invitee_display_name: String?
    let created_at: Date
  }

  func fetchPendingInvitations(wordSetId: UUID) async throws -> [PendingInvitee] {
    let rows: [PendingInviteeRow] = try await client
      .rpc("get_word_set_pending_invitations", params: ["p_word_set_id": wordSetId.uuidString])
      .execute()
      .value

    return rows.map { row in
      PendingInvitee(
        invitationId: row.invitation_id,
        inviteeId: row.invitee_id,
        inviteeDisplayName: row.invitee_display_name ?? "使用者",
        createdAt: row.created_at
      )
    }
  }
}
