// WordSet.swift
// Word Set / Deck model for organizing cards into groups

import Foundation
import SwiftData

enum WordSetIconType: String, CaseIterable, Identifiable {
  case emoji = "emoji"
  case image = "image"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .emoji: return "Emoji"
    case .image: return "圖片"
    }
  }
}

@Model
final class WordSet {
  @Attribute(.unique) var id: UUID
  var title: String          // e.g. "韓文第六課"
  var level: String?         // e.g. "初級", "中級", "高級"
  var createdAt: Date

  // ✅ 新增：單字集圖示
  @Attribute var iconTypeRaw: String = WordSetIconType.emoji.rawValue
  @Attribute var iconEmoji: String = "📘"
  @Attribute var iconImageData: Data? = nil

  @Relationship(deleteRule: .cascade, inverse: \Card.wordSet) var cards: [Card] = []

  var iconType: WordSetIconType {
    get { WordSetIconType(rawValue: iconTypeRaw) ?? .emoji }
    set { iconTypeRaw = newValue.rawValue }
  }

  init(title: String, level: String? = nil) {
    self.id = UUID()
    self.title = title
    self.level = level
    self.createdAt = Date()
    self.cards = []

    // default icon
    self.iconTypeRaw = WordSetIconType.emoji.rawValue
    self.iconEmoji = "📘"
    self.iconImageData = nil
  }
}
