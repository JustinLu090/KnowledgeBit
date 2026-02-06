// UserProfile.swift
// 儲存用戶的個人資料（頭貼和名字）

import Foundation
import SwiftData

@Model
final class UserProfile {
  @Attribute(.unique) var userId: UUID  // 對應 Supabase 的 user.id
  var displayName: String
  var avatarData: Data?  // 頭貼圖片資料（儲存在資料庫中）
  var avatarURL: String?  // Google 頭貼 URL（僅用於遠端載入）
  var level: Int  // 用戶等級
  var currentExp: Int  // 當前經驗值
  var updatedAt: Date
  
  init(userId: UUID, displayName: String = "使用者", avatarData: Data? = nil, avatarURL: String? = nil, level: Int = 1, currentExp: Int = 0) {
    self.userId = userId
    self.displayName = displayName
    self.avatarData = avatarData
    self.avatarURL = avatarURL
    self.level = level
    self.currentExp = currentExp
    self.updatedAt = Date()
  }
}
