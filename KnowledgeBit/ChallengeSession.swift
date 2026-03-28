// ChallengeSession.swift
// 非同步挑戰模式的資料模型，對應 Supabase challenge_sessions 表

import Foundation

// MARK: - ChallengeSession

/// 一場挑戰的完整資料，對應 Supabase `challenge_sessions` 表
struct ChallengeSession: Codable, Identifiable {
  let id: UUID

  // 發起者
  let challengerId: UUID
  let challengerDisplayName: String?
  let challengerAvatarUrl: String?
  let challengerLevel: Int

  // 單字集
  let wordSetId: UUID?
  let wordSetTitle: String

  // 發起者成績
  let challengerScore: Int
  let challengerTotal: Int
  let challengerTimeSpent: Double?     // 秒
  let challengerCompletedAt: Date

  /// 接受者需超越的目標分數（初始等於 challengerScore，未來可獨立設定門檻）
  let targetScore: Int?

  // 接受者（回應後填入）
  var respondentId: UUID?
  var respondentDisplayName: String?
  var respondentScore: Int?
  var respondentTotal: Int?
  var respondentTimeSpent: Double?
  var respondentCompletedAt: Date?

  // 狀態
  let status: String   // "pending" | "completed" | "expired"
  let createdAt: Date
  let expiresAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case challengerId             = "challenger_id"
    case challengerDisplayName    = "challenger_display_name"
    case challengerAvatarUrl      = "challenger_avatar_url"
    case challengerLevel          = "challenger_level"
    case wordSetId                = "word_set_id"
    case wordSetTitle             = "word_set_title"
    case challengerScore          = "challenger_score"
    case challengerTotal          = "challenger_total"
    case challengerTimeSpent      = "challenger_time_spent"
    case challengerCompletedAt    = "challenger_completed_at"
    case targetScore              = "target_score"
    case respondentId             = "respondent_id"
    case respondentDisplayName    = "respondent_display_name"
    case respondentScore          = "respondent_score"
    case respondentTotal          = "respondent_total"
    case respondentTimeSpent      = "respondent_time_spent"
    case respondentCompletedAt    = "respondent_completed_at"
    case status
    case createdAt                = "created_at"
    case expiresAt                = "expires_at"
  }

  // MARK: - Computed

  var challengerAccuracy: Int {
    guard challengerTotal > 0 else { return 0 }
    return Int(Double(challengerScore) / Double(challengerTotal) * 100)
  }

  var respondentAccuracy: Int? {
    guard let s = respondentScore, let t = respondentTotal, t > 0 else { return nil }
    return Int(Double(s) / Double(t) * 100)
  }

  var isPending: Bool { status == "pending" }
  var isCompleted: Bool { status == "completed" }
  var isExpired: Bool { status == "expired" || expiresAt < Date() }

  /// 挑戰是否已過期（不論 status 欄位）
  var isEffectivelyExpired: Bool { isExpired }
}

// MARK: - ChallengeCard

/// 用於挑戰測驗的輕量卡片（不依賴 SwiftData，從 Supabase 直接取得）
struct ChallengeCard: Codable, Identifiable {
  let id: UUID
  let title: String    // 正面（問題）
  let content: String  // 背面（答案）
}

// MARK: - ChallengeResult

/// 比較發起者與接受者後的最終結果
enum ChallengeResult {
  case won   // 接受者贏
  case lost  // 接受者輸
  case tied  // 平手
}

extension ChallengeSession {
  /// 從接受者角度判斷勝負（分數高者勝，分數相同比時間短）
  func resultForRespondent() -> ChallengeResult? {
    guard let rScore = respondentScore,
          let rTotal = respondentTotal, rTotal > 0,
          challengerTotal > 0 else { return nil }

    let rAcc = Double(rScore) / Double(rTotal)
    let cAcc = Double(challengerScore) / Double(challengerTotal)

    if rAcc > cAcc { return .won }
    if rAcc < cAcc { return .lost }

    // 準確率相同：比時間（短者勝）
    if let rTime = respondentTimeSpent, let cTime = challengerTimeSpent {
      if rTime < cTime { return .won }
      if rTime > cTime { return .lost }
    }
    return .tied
  }
}
