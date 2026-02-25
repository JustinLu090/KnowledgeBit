// WordSetIconType.swift
// Lightweight enum used by AddWordSetView

import Foundation

public enum WordSetIconType: String, CaseIterable, Codable, Identifiable {
  case emoji
  case image

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .emoji: return "Emoji"
    case .image: return "圖片"
    }
  }
}
