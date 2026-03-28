// ChallengeService.swift
// 非同步挑戰模式的 Supabase CRUD 與 Deep Link 產生

import Foundation
import Supabase

@MainActor
final class ChallengeService {

  private let client: SupabaseClient
  private let authService: AuthService

  init(authService: AuthService) {
    self.authService = authService
    self.client = authService.getClient()
  }

  // MARK: - Deep Link

  /// 產生挑戰分享連結：`knowledgebit://challenge?id=<id>`
  static func deepLink(for challengeId: UUID) -> URL {
    URL(string: "knowledgebit://challenge?id=\(challengeId.uuidString)")!
  }

  // MARK: - 建立挑戰

  /// 使用者完成測驗後呼叫：將成績上傳，回傳新建立的 challengeId
  func createChallenge(
    wordSetId: UUID?,
    wordSetTitle: String,
    score: Int,
    total: Int,
    timeSpent: TimeInterval
  ) async throws -> UUID {
    guard let userId = authService.currentUserId else {
      throw ChallengeError.notLoggedIn
    }

    // 取得顯示名稱與等級（從 AppGroup UserDefaults，已由 AuthService 填入）
    let displayName = AppGroup.sharedUserDefaults()?.string(forKey: AppGroup.Keys.displayName)
    let avatarUrl   = AppGroup.sharedUserDefaults()?.string(forKey: AppGroup.Keys.avatarURL)
    let level       = AppGroup.sharedUserDefaults()?.integer(forKey: AppGroup.Keys.level) ?? 1

    struct InsertBody: Encodable {
      let challenger_id: UUID
      let challenger_display_name: String?
      let challenger_avatar_url: String?
      let challenger_level: Int
      let word_set_id: UUID?
      let word_set_title: String
      let challenger_score: Int
      let challenger_total: Int
      let challenger_time_spent: Double
      let target_score: Int  // 接受者須超越的目標分數（初始等於 challenger_score）
    }

    struct ReturnedId: Decodable {
      let id: UUID
    }

    let body = InsertBody(
      challenger_id: userId,
      challenger_display_name: displayName,
      challenger_avatar_url: avatarUrl,
      challenger_level: level,
      word_set_id: wordSetId,
      word_set_title: wordSetTitle,
      challenger_score: score,
      challenger_total: total,
      challenger_time_spent: timeSpent,
      target_score: score
    )

    let rows: [ReturnedId] = try await client
      .from("challenge_sessions")
      .insert(body)
      .select("id")
      .execute()
      .value

    guard let first = rows.first else { throw ChallengeError.createFailed }
    return first.id
  }

  // MARK: - 讀取挑戰

  /// 依 challengeId 取得挑戰完整資訊
  func fetchChallenge(id: UUID) async throws -> ChallengeSession {
    let rows: [ChallengeSession] = try await client
      .from("challenge_sessions")
      .select()
      .eq("id", value: id)
      .limit(1)
      .execute()
      .value

    guard let challenge = rows.first else { throw ChallengeError.notFound }
    return challenge
  }

  // MARK: - 讀取挑戰卡片

  /// 取得挑戰所使用的單字卡（直接從 Supabase cards 表查詢，需對應 RLS policy）
  func fetchChallengeCards(wordSetId: UUID) async throws -> [ChallengeCard] {
    struct CardRow: Decodable {
      let id: UUID
      let title: String
      let content: String
    }
    let rows: [CardRow] = try await client
      .from("cards")
      .select("id, title, content")
      .eq("word_set_id", value: wordSetId)
      .execute()
      .value

    return rows.map { ChallengeCard(id: $0.id, title: $0.title, content: $0.content) }
  }

  // MARK: - 回應挑戰

  /// 接受者完成測驗後呼叫，將成績寫回並更新狀態為 completed
  func respondToChallenge(
    challengeId: UUID,
    score: Int,
    total: Int,
    timeSpent: TimeInterval
  ) async throws {
    guard let userId = authService.currentUserId else { throw ChallengeError.notLoggedIn }

    let displayName = AppGroup.sharedUserDefaults()?.string(forKey: AppGroup.Keys.displayName)

    struct UpdateBody: Encodable {
      let respondent_id: UUID
      let respondent_display_name: String?
      let respondent_score: Int
      let respondent_total: Int
      let respondent_time_spent: Double
      let respondent_completed_at: String // ISO8601
      let status: String
    }

    let iso = ISO8601DateFormatter()
    let body = UpdateBody(
      respondent_id: userId,
      respondent_display_name: displayName,
      respondent_score: score,
      respondent_total: total,
      respondent_time_spent: timeSpent,
      respondent_completed_at: iso.string(from: Date()),
      status: "completed"
    )

    try await client
      .from("challenge_sessions")
      .update(body)
      .eq("id", value: challengeId)
      .execute()
  }

  // MARK: - 社群動態：近期朋友發起的挑戰

  /// 取得好友近期發起的挑戰（供 CommunityView 顯示動態）
  func fetchRecentChallengesByFriends(friendIds: [UUID], limit: Int = 10) async throws -> [ChallengeSession] {
    guard !friendIds.isEmpty else { return [] }
    let idList = friendIds.map { $0.uuidString }.joined(separator: ",")
    let rows: [ChallengeSession] = try await client
      .from("challenge_sessions")
      .select()
      .in("challenger_id", values: friendIds.map { $0.uuidString })
      .order("created_at", ascending: false)
      .limit(limit)
      .execute()
      .value
    _ = idList  // suppress unused warning
    return rows
  }

  // MARK: - 我的挑戰歷史

  func fetchMyChallenges(limit: Int = 20) async throws -> [ChallengeSession] {
    guard let userId = authService.currentUserId else { return [] }
    let rows: [ChallengeSession] = try await client
      .from("challenge_sessions")
      .select()
      .or("challenger_id.eq.\(userId),respondent_id.eq.\(userId)")
      .order("created_at", ascending: false)
      .limit(limit)
      .execute()
      .value
    return rows
  }

  // MARK: - 錯誤

  enum ChallengeError: LocalizedError {
    case notLoggedIn
    case createFailed
    case notFound

    var errorDescription: String? {
      switch self {
      case .notLoggedIn:  return "請先登入才能發送挑戰"
      case .createFailed: return "挑戰建立失敗，請稍後再試"
      case .notFound:     return "找不到此挑戰，連結可能已過期"
      }
    }
  }
}
