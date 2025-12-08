// Card.swift
import Foundation
import SwiftData

@Model
final class Card {
  var id: UUID
  var title: String       // 例如：TCP Handshake
  var content: String     // 詳細解釋 (Markdown)
  var deck: String        // 分類，例如：CS, Japan, Physics
  var isMastered: Bool    // 是否已精通
  var createdAt: Date

  init(title: String, content: String, deck: String = "General") {
    self.id = UUID()
    self.title = title
    self.content = content
    self.deck = deck
    self.isMastered = false
    self.createdAt = Date()
  }
}

@Model
final class StudyLog {
  var id: UUID
  var date: Date          // 打卡日期
  var cardsReviewed: Int  // 今天複習了幾張

  init(date: Date, cardsReviewed: Int) {
    self.id = UUID()
    self.date = date
    self.cardsReviewed = cardsReviewed
  }
}
