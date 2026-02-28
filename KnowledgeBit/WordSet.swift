// WordSet.swift
// Word Set / Deck model for organizing cards into groups

import Foundation
import SwiftData

@Model
final class WordSet {
  @Attribute(.unique) var id: UUID
  var title: String          // e.g. "英文"
  var level: String?         // e.g. "初級", "中級", "高級"
  var createdAt: Date
  /// 擁有這個單字集的使用者（本機用來區分不同帳號）
  var ownerUserId: UUID?
  
  @Relationship(deleteRule: .cascade, inverse: \Card.wordSet) var cards: [Card] = []

  /// 建立本機新的單字集（自動產生 id）
  init(title: String, level: String? = nil, ownerUserId: UUID? = nil) {
    self.id = UUID()
    self.title = title
    self.level = level
    self.createdAt = Date()
    self.ownerUserId = ownerUserId
    self.cards = []
  }

  /// 從雲端同步指定 id 的單字集到本機時使用
  init(id: UUID, title: String, level: String? = nil, createdAt: Date, ownerUserId: UUID? = nil) {
    self.id = id
    self.title = title
    self.level = level
    self.createdAt = createdAt
    self.ownerUserId = ownerUserId
    self.cards = []
  }
}

