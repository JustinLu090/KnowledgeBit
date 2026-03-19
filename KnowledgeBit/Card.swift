// Card.swift
import Foundation
import SwiftData
import Combine

@Model
final class Card {
  var id: UUID
  var title: String       // 例如：TCP Handshake
  var content: String     // 詳細解釋 (Markdown)
  var isMastered: Bool    // 是否已精通
  var createdAt: Date
  
  // Optional relationship to WordSet
  var wordSet: WordSet?
  
  // SRS (Spaced Repetition System) 相關欄位
  @Attribute var srsLevel: Int = 0       // SRS 等級（預設 0）
  @Attribute var dueAt: Date = Date()    // 下次複習時間（預設現在）
  var lastReviewedAt: Date?  // 最後複習時間（可選）
  @Attribute var correctStreak: Int = 0  // 連續答對次數（預設 0）

  init(title: String, content: String, wordSet: WordSet? = nil) {
    self.id = UUID()
    self.title = title
    self.content = content
    self.isMastered = false
    self.createdAt = Date()
    self.wordSet = wordSet
    
    // SRS 預設值
    self.srsLevel = 0
    self.dueAt = Date()  // 新卡片立即到期
    self.lastReviewedAt = nil
    self.correctStreak = 0
  }
}

@Model
final class StudyLog {
  var id: UUID
  var date: Date          // 打卡日期
  var cardsReviewed: Int  // 該次測驗答對數（記住的張數）
  var totalCards: Int     // 該次測驗總張數（用於計算正確率）
  /// 用於統計/成就過濾（例如：只統計 multiple choice quiz，不把翻卡學習算進去）
  /// 既有資料可能為 nil（舊版本寫入），統計時會被排除以避免誤判
  var activityType: String?

  init(date: Date, cardsReviewed: Int, totalCards: Int = 0, activityType: String? = nil) {
    self.id = UUID()
    self.date = date
    self.cardsReviewed = cardsReviewed
    self.totalCards = totalCards
    self.activityType = activityType
  }
}
