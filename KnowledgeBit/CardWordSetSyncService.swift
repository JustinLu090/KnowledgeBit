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

  /// 僅單字集擁有者會寫入 Supabase；共編者不應 upsert 別人的 word_sets（會觸發 RLS 拒絕）。
  func syncWordSet(_ wordSet: WordSet) async {
    let isOwner = wordSet.ownerUserId == nil || wordSet.ownerUserId == currentUserId
    guard isOwner else { return }

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

  // MARK: - 從 Supabase 拉取可見單字集並寫入本機（擁有 + 共編）

  /// 從 Supabase 拉取該單字集內所有卡片（擁有者與共編者皆可讀），若本機尚無則建立一筆並關聯到 wordSet。
  /// 共編時一方新增單字卡後，另一方進入此單字集時呼叫即可看到最新卡片。
  func pullCardsForWordSet(wordSet: WordSet, modelContext: ModelContext) async {
    struct RemoteCard: Decodable {
      let id: UUID
      let title: String
      let content: String
      let is_mastered: Bool
      let srs_level: Int
      let due_at: Date
      let last_reviewed_at: Date?
      let correct_streak: Int
      let created_at: Date
    }
    do {
      let rows: [RemoteCard] = try await client
        .rpc("get_cards_for_word_set", params: ["p_word_set_id": wordSet.id.uuidString])
        .execute()
        .value

      let existingIds = Set(wordSet.cards.map(\.id))
      for row in rows where !existingIds.contains(row.id) {
        let card = Card(title: row.title, content: row.content, wordSet: wordSet)
        card.id = row.id
        card.createdAt = row.created_at
        card.isMastered = row.is_mastered
        card.srsLevel = row.srs_level
        card.dueAt = row.due_at
        card.lastReviewedAt = row.last_reviewed_at
        card.correctStreak = row.correct_streak
        modelContext.insert(card)
      }
      try? modelContext.save()
    } catch {
      print("⚠️ [Sync] pullCardsForWordSet 失敗: \(error.localizedDescription)")
    }
  }

  /// 取得目前使用者可見的 word_sets（擁有者或共編者），若本機尚無則建立一筆，供「我的單字集」列表顯示。
  /// 接受邀請後呼叫此方法可讓新單字集立即出現在列表中。
  func pullVisibleWordSetsAndMergeToLocal(modelContext: ModelContext) async {
    struct RemoteWordSet: Decodable {
      let id: UUID
      let user_id: UUID
      let title: String
      let level: String?
      let created_at: Date
    }
    do {
      let rows: [RemoteWordSet] = try await client
        .rpc("get_visible_word_sets")
        .execute()
        .value

      let existingAll = (try? modelContext.fetch(FetchDescriptor<WordSet>())) ?? []
      for row in rows {
        if let existing = existingAll.first(where: { $0.id == row.id }) {
          // 更新本機紀錄的真正擁有者（word_sets.user_id），以便之後區分「創辦人」與「共編者」
          existing.ownerUserId = row.user_id
        } else {
          let local = WordSet(
            id: row.id,
            title: row.title,
            level: row.level,
            createdAt: row.created_at,
            ownerUserId: row.user_id
          )
          modelContext.insert(local)
        }
      }
      try? modelContext.save()
    } catch {
      print("⚠️ [Sync] pullVisibleWordSetsAndMergeToLocal 失敗: \(error.localizedDescription)")
    }
  }
}
