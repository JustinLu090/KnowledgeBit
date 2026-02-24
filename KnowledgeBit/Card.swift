// Card.swift
import Foundation
import SwiftData
import Combine

// MARK: - Card Kind

enum CardKind: String, CaseIterable, Identifiable {
  case qa = "qa"         // 問題/答案
  case quote = "quote"   // 語錄

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .qa: return "問題 / 答案"
    case .quote: return "語錄"
    }
  }
}

@Model
final class Card {
  var id: UUID

  /// QA: 問題/標題；Quote: 一句語錄
  var title: String

  /// ✅ QA: 簡答（先顯示）；Quote: 建議保持空字串
  @Attribute var shortAnswer: String = ""

  /// QA: 詳細說明 (Markdown)；Quote: 建議保持空字串
  var content: String

  var isMastered: Bool
  var createdAt: Date

  /// 卡片種類（用 raw string 存）
  @Attribute var kindRaw: String = CardKind.qa.rawValue

  /// Optional relationship to WordSet
  var wordSet: WordSet?

  // SRS (Spaced Repetition System) 相關欄位
  @Attribute var srsLevel: Int = 0
  @Attribute var dueAt: Date = Date()
  var lastReviewedAt: Date?
  @Attribute var correctStreak: Int = 0

  /// enum 介面
  var kind: CardKind {
    get { CardKind(rawValue: kindRaw) ?? .qa }
    set { kindRaw = newValue.rawValue }
  }

  init(
    title: String,
    shortAnswer: String = "",
    content: String,
    wordSet: WordSet? = nil,
    kind: CardKind = .qa
  ) {
    self.id = UUID()
    self.title = title
    self.shortAnswer = shortAnswer
    self.content = content
    self.isMastered = false
    self.createdAt = Date()
    self.wordSet = wordSet

    self.kindRaw = kind.rawValue

    // SRS defaults
    self.srsLevel = 0
    self.dueAt = Date()
    self.lastReviewedAt = nil
    self.correctStreak = 0
  }
}

@Model
final class StudyLog {
  var id: UUID
  var date: Date
  var cardsReviewed: Int
  var totalCards: Int

  init(date: Date, cardsReviewed: Int, totalCards: Int = 0) {
    self.id = UUID()
    self.date = date
    self.cardsReviewed = cardsReviewed
    self.totalCards = totalCards
  }
}
