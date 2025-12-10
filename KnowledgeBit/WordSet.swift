// WordSet.swift
// Word Set / Deck model for organizing cards into groups

import Foundation
import SwiftData

@Model
final class WordSet {
  @Attribute(.unique) var id: UUID
  var title: String          // e.g. "韓文第六課"
  var level: String?         // e.g. "初級", "中級", "高級"
  var createdAt: Date
  
  @Relationship(deleteRule: .cascade, inverse: \Card.wordSet) var cards: [Card] = []
  
  init(title: String, level: String? = nil) {
    self.id = UUID()
    self.title = title
    self.level = level
    self.createdAt = Date()
    self.cards = []
  }
}

