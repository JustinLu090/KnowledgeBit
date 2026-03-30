// AppLog.swift
// 統一使用 os.Logger，取代 print；可在 Console 依 category 過濾。

import Foundation
import os

enum AppLog {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "KnowledgeBit"

  static let app = Logger(subsystem: subsystem, category: "App")
  static let model = Logger(subsystem: subsystem, category: "ModelContainer")
  static let auth = Logger(subsystem: subsystem, category: "Auth")
  static let ai = Logger(subsystem: subsystem, category: "AIService")
  static let quest = Logger(subsystem: subsystem, category: "Quest")
  static let stats = Logger(subsystem: subsystem, category: "Statistics")
  static let exp = Logger(subsystem: subsystem, category: "Experience")
  static let srs = Logger(subsystem: subsystem, category: "SRS")
  static let task = Logger(subsystem: subsystem, category: "Task")
  static let battle = Logger(subsystem: subsystem, category: "Battle")
  static let community = Logger(subsystem: subsystem, category: "Community")
  static let sync = Logger(subsystem: subsystem, category: "Sync")
  static let notif = Logger(subsystem: subsystem, category: "Notification")
  static let speech = Logger(subsystem: subsystem, category: "Speech")
  static let wordset = Logger(subsystem: subsystem, category: "WordSet")
  static let widget = Logger(subsystem: subsystem, category: "Widget")
  static let heatmap = Logger(subsystem: subsystem, category: "Heatmap")
  static let card = Logger(subsystem: subsystem, category: "Card")
}
