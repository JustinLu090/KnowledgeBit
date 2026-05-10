// WidgetSyncService.swift
// 將使用者 profile / 經驗值寫入 App Group UserDefaults 供 Widget 讀取，
// 並適時觸發 WidgetCenter reload。
//
// 從 AuthService 抽出以分離職責：AuthService 只管登入/Session，
// 與 Widget 共享資料的細節由本服務負責，方便獨立測試與替換。

import Foundation
import WidgetKit
import os

@MainActor
final class WidgetSyncService {
  private let defaults: UserDefaults?
  private let reloadAll: () -> Void
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.knowledgebit",
    category: "WidgetSync"
  )

  /// - Parameters:
  ///   - defaults: App Group UserDefaults。預設使用 `AppGroup.sharedUserDefaults()`；
  ///               測試時可注入自訂 defaults 並關閉 reload。
  ///   - reloadAll: 觸發 Widget reload 的 callback；測試時可注入 no-op 以避免實際刷新。
  init(
    defaults: UserDefaults? = AppGroup.sharedUserDefaults(),
    reloadAll: @escaping () -> Void = { WidgetReloader.reloadAll() }
  ) {
    self.defaults = defaults
    self.reloadAll = reloadAll
  }

  // MARK: - Profile

  /// 寫入 displayName / avatarURL / userId 到 App Group。
  /// - Parameter shouldReloadWidget: 預設 true 立即刷新；批次同步時設為 false 由 syncBatch 統一處理。
  func syncProfile(
    displayName: String,
    avatarURL: String?,
    userId: UUID?,
    shouldReloadWidget: Bool = true
  ) {
    guard let defaults else {
      logger.notice("sharedUserDefaults 為 nil，請確認 Signing & Capabilities 已設定 App Groups")
      return
    }
    defaults.set(displayName, forKey: AppGroup.Keys.displayName)
    defaults.set(avatarURL, forKey: AppGroup.Keys.avatarURL)
    if let id = userId {
      defaults.set(id.uuidString, forKey: AppGroup.Keys.userId)
    }
    if shouldReloadWidget { reloadAll() }
  }

  // MARK: - Experience

  /// 寫入 level / exp / expToNext 到 App Group。
  func syncExp(
    level: Int,
    exp: Int,
    expToNext: Int,
    shouldReloadWidget: Bool = true
  ) {
    guard let defaults else {
      logger.notice("sharedUserDefaults 為 nil，請確認 Signing & Capabilities 已設定 App Groups")
      return
    }
    defaults.set(level, forKey: AppGroup.Keys.level)
    defaults.set(exp, forKey: AppGroup.Keys.exp)
    defaults.set(expToNext, forKey: AppGroup.Keys.expToNext)
    logger.info("已同步等級與經驗值 - Level: \(level), EXP: \(exp)/\(expToNext)")
    if shouldReloadWidget { reloadAll() }
  }

  // MARK: - Batch

  /// 一次寫入多個欄位並僅觸發一次 Widget reload。傳 nil 的欄位不會更新。
  /// 注意：傳 displayName 但 avatarURL 為 nil 表示「明確清除頭像」。
  func syncBatch(
    displayName: String? = nil,
    avatarURL: String? = nil,
    userId: UUID? = nil,
    level: Int? = nil,
    exp: Int? = nil,
    expToNext: Int? = nil
  ) {
    guard let defaults else {
      logger.notice("sharedUserDefaults 為 nil，請確認 Signing & Capabilities 已設定 App Groups")
      return
    }

    var hasUpdates = false

    if let name = displayName {
      defaults.set(name, forKey: AppGroup.Keys.displayName)
      hasUpdates = true
    }
    if let url = avatarURL {
      defaults.set(url, forKey: AppGroup.Keys.avatarURL)
      hasUpdates = true
    } else if avatarURL == nil && displayName != nil {
      defaults.removeObject(forKey: AppGroup.Keys.avatarURL)
      hasUpdates = true
    }
    if let id = userId, (displayName != nil || avatarURL != nil) {
      defaults.set(id.uuidString, forKey: AppGroup.Keys.userId)
      hasUpdates = true
    }
    if let lvl = level {
      defaults.set(lvl, forKey: AppGroup.Keys.level)
      hasUpdates = true
    }
    if let e = exp {
      defaults.set(e, forKey: AppGroup.Keys.exp)
      hasUpdates = true
    }
    if let etn = expToNext {
      defaults.set(etn, forKey: AppGroup.Keys.expToNext)
      hasUpdates = true
    }

    if hasUpdates {
      logger.info("批次同步完成 - displayName: \(displayName ?? "未更新", privacy: .public), level: \(level?.description ?? "未更新", privacy: .public), exp: \(exp?.description ?? "未更新", privacy: .public)")
      reloadAll()
    }
  }

  // MARK: - Logout

  /// 登出時清除 App Group 中的 profile 快取。
  func clearProfile() {
    guard let defaults else { return }
    defaults.removeObject(forKey: AppGroup.Keys.displayName)
    defaults.removeObject(forKey: AppGroup.Keys.avatarURL)
    defaults.removeObject(forKey: AppGroup.Keys.userId)
  }
}
