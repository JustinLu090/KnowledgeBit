// AppGroup.swift
// Shared App Group identifier for data synchronization between main app and widget extension

import Foundation

enum AppGroup {
  /// App Group identifier for sharing SwiftData container between main app and widget
  /// Update this value to match your App Group ID configured in Xcode Signing & Capabilities
  static let identifier = "group.com.team.knowledgebit"
  
  /// 取得 App Group 共用的 UserDefaults。
  /// 讀寫請在主線程執行，以避免 CFPrefsPlistSource 相關錯誤。
  static func sharedUserDefaults() -> UserDefaults? {
    UserDefaults(suiteName: identifier)
  }
  
  // MARK: - UserDefaults Keys
  
  /// UserDefaults Key 常數定義（避免硬編碼字串）
  enum Keys {
    // 用戶資料
    static let displayName = "appgroup_user_display_name"
    static let avatarURL = "appgroup_user_avatar_url"
    static let userId = "appgroup_user_id"
    
    // 經驗值與等級
    static let level = "userLevel"
    static let exp = "userExp"
    static let expToNext = "expToNext"
    
    // Widget 相關
    static let todayDueCount = "today_due_count"
  }
  
  // MARK: - Supabase 欄位名稱
  
  /// Supabase 資料庫欄位名稱常數定義（避免硬編碼字串）
  enum SupabaseFields {
    static let displayName = "display_name"
    static let currentExp = "current_exp"
    static let avatarURL = "avatar_url"
    static let userId = "user_id"
    static let level = "level"
    static let updatedAt = "updated_at"
  }
}

