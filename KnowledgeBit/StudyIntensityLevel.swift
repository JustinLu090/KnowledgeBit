// StudyIntensityLevel.swift
// 共用：學習強度等級（藍色階層，用於週曆與熱力圖）

import SwiftUI

/// 視覺強度等級（0 / 1–2 / 3–5 / 6–9 / 10+，藍色由淺到深）
enum StudyIntensityLevel: Int, CaseIterable {
  case none = 0   // 0
  case low = 1    // 1–2
  case medium = 2 // 3–5
  case high = 3   // 6–9
  case max = 4    // 10+
  
  static func from(cardCount: Int) -> StudyIntensityLevel {
    switch cardCount {
    case 0: return .none
    case 1...2: return .low
    case 3...5: return .medium
    case 6...9: return .high
    default: return .max
    }
  }
  
  /// 藍色階層
  var color: Color {
    switch self {
    case .none: return Color(.systemGray6)
    case .low: return Color.blue.opacity(0.2)
    case .medium: return Color.blue.opacity(0.5)
    case .high: return Color.blue.opacity(0.8)
    case .max: return Color.blue
    }
  }
}
