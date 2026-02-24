// CardWordSetSyncService.swift
// 在 SwiftData 寫入成功後，將 word_sets 與 cards 同步至 Supabase（單向寫入）

import Foundation
import Supabase
import SwiftData

@MainActor
final class CardWordSetSyncService {
  private let client: SupabaseClient
  private let currentUserId: UUID

  init(authService: AuthService) {
    self.client = authService.getClient()
    guard let userId = authService.currentUserId else {
      fatalError("CardWordSetSyncService requires a logged-in user")
    }
    self.currentUserId = userId
  }

  /// 未登入時回傳 nil，呼叫端應跳過 sync
  static func createIfLoggedIn(authService: AuthService) -> CardWordSetSyncService? {
    guard authService.currentUserId != nil else { return nil }
    return CardWordSetSyncService(authService: authService)
  }

  // MARK: - word_sets

  private static let iso8601: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  private static func formatDate(_ date: Date) -> String {
    iso8601.string(from: date)
  }

  func syncWordSet(_ wordSet: WordSet) async {
    struct Payload: Encodable {
      let id: UUID
      let user_id: UUID
      let title: String
      let level: String?
      let created_at: String

      enum CodingKeys: String, CodingKey {
        case id, user_id, title, level, created_at
      }
    }
    let payload = Payload(
      id: wordSet.id,
      user_id: currentUserId,
      title: wordSet.title,
      level: wordSet.level,
      created_at: Self.formatDate(wordSet.createdAt)
    )
    do {
      try await client.from("word_sets")
        .upsert(payload, onConflict: "id")
        .execute()
    } catch {
      print("⚠️ [Sync] word_sets upsert 失敗: \(error.localizedDescription)")
    }
  }

  func deleteWordSet(id: UUID) async {
    do {
      try await client.from("word_sets")
        .delete()
        .eq("id", value: id)
        .eq("user_id", value: currentUserId)
        .execute()
    } catch {
      print("⚠️ [Sync] word_sets delete 失敗: \(error.localizedDescription)")
    }
  }

  // MARK: - cards

  func syncCard(_ card: Card) async {
    struct Payload: Encodable {
      let id: UUID
      let user_id: UUID
      let word_set_id: UUID?
      let title: String
      let content: String
      let is_mastered: Bool
      let srs_level: Int
      let due_at: String
      let last_reviewed_at: String?
      let correct_streak: Int
      let created_at: String

      enum CodingKeys: String, CodingKey {
        case id, user_id, word_set_id, title, content, is_mastered
        case srs_level, due_at, last_reviewed_at, correct_streak, created_at
      }
    }
    let payload = Payload(
      id: card.id,
      user_id: currentUserId,
      word_set_id: card.wordSet?.id,
      title: card.title,
      content: card.content,
      is_mastered: card.isMastered,
      srs_level: card.srsLevel,
      due_at: Self.formatDate(card.dueAt),
      last_reviewed_at: card.lastReviewedAt.map(Self.formatDate),
      correct_streak: card.correctStreak,
      created_at: Self.formatDate(card.createdAt)
    )
    do {
      try await client.from("cards")
        .upsert(payload, onConflict: "id")
        .execute()
    } catch {
      print("⚠️ [Sync] cards upsert 失敗: \(error.localizedDescription)")
    }
  }

  func deleteCard(id: UUID) async {
    do {
      try await client.from("cards")
        .delete()
        .eq("id", value: id)
        .eq("user_id", value: currentUserId)
        .execute()
    } catch {
      print("⚠️ [Sync] cards delete 失敗: \(error.localizedDescription)")
    }
  }

  /// 刪除某 word_set 下所有 cards（在刪除 word_set 前呼叫，或由 DB CASCADE 處理）
  func deleteCardsInWordSet(wordSetId: UUID) async {
    do {
      try await client.from("cards")
        .delete()
        .eq("word_set_id", value: wordSetId)
        .eq("user_id", value: currentUserId)
        .execute()
    } catch {
      print("⚠️ [Sync] cards delete by word_set_id 失敗: \(error.localizedDescription)")
    }
  }
}
