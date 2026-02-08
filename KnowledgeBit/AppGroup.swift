// AppGroup.swift
// Shared App Group identifier for data synchronization between main app and widget extension

import Foundation

enum AppGroup {
  /// App Group identifier for sharing SwiftData container between main app and widget
  /// Update this value to match your App Group ID configured in Xcode Signing & Capabilities
  static let identifier = "group.com.KnowledgeBit"
  
  /// 取得 App Group 共用的 UserDefaults。讀寫請在主線程執行，以避免 CFPrefsPlistSource 相關錯誤。
  static func sharedUserDefaults() -> UserDefaults? {
    UserDefaults(suiteName: identifier)
  }
}

