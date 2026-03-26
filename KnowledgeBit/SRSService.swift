// SRSService.swift
// 處理 SRS (Spaced Repetition System) 相關邏輯

import Foundation
import SwiftData
#if os(iOS)
import WidgetKit
#endif

enum ReviewResult {
  case remembered
  case forgotten
}

// MARK: - 純規則（供 SRSService 與單元測試共用）
enum SRSRules {
  /// 根據複習後的 `srsLevel` 返回「距離下次複習」的時間間隔
  static func intervalForLevel(_ level: Int) -> TimeInterval {
    switch level {
    case 0: return 10 * 60
    case 1: return 1 * 24 * 60 * 60
    case 2: return 3 * 24 * 60 * 60
    case 3: return 7 * 24 * 60 * 60
    case 4: return 14 * 24 * 60 * 60
    case 5: return 30 * 24 * 60 * 60
    default:
      let extraDays = (level - 5) * 30
      return TimeInterval(extraDays * 24 * 60 * 60)
    }
  }

  struct ReviewMutation {
    let newLevel: Int
    let newCorrectStreak: Int
    let dueInterval: TimeInterval
  }

  /// 複習一次後的等級、連勝與下次複習間隔（不含寫入 SwiftData）
  static func mutation(oldLevel: Int, oldCorrectStreak: Int, result: ReviewResult) -> ReviewMutation {
    switch result {
    case .remembered:
      let newLevel = oldLevel + 1
      return ReviewMutation(
        newLevel: newLevel,
        newCorrectStreak: oldCorrectStreak + 1,
        dueInterval: intervalForLevel(newLevel)
      )
    case .forgotten:
      return ReviewMutation(newLevel: 0, newCorrectStreak: 0, dueInterval: intervalForLevel(0))
    }
  }
}

class SRSService {
  private let userDefaults: UserDefaults
  
  init() {
    if let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) {
      self.userDefaults = sharedDefaults
    } else {
      print("⚠️ [SRS] 無法取得 App Group UserDefaults，回退到標準 UserDefaults")
      self.userDefaults = .standard
    }
  }
  
  // MARK: - 查詢到期卡片
  // 取得所有到期的卡片（dueAt <= now）
  func getDueCards(now: Date = Date(), context: ModelContext) -> [Card] {
    let descriptor = FetchDescriptor<Card>(
      predicate: #Predicate<Card> { card in
        card.dueAt <= now
      },
      sortBy: [SortDescriptor(\.dueAt, order: .forward)]
    )
    
    do {
      return try context.fetch(descriptor)
    } catch {
      print("❌ [SRS] 查詢到期卡片失敗: \(error.localizedDescription)")
      return []
    }
  }
  
  // MARK: - 應用複習結果
  // 根據複習結果更新卡片狀態
  func applyReview(card: Card, result: ReviewResult, now: Date = Date()) {
    let oldLevel = card.srsLevel
    let m = SRSRules.mutation(oldLevel: card.srsLevel, oldCorrectStreak: card.correctStreak, result: result)
    card.srsLevel = m.newLevel
    card.correctStreak = m.newCorrectStreak
    card.dueAt = now.addingTimeInterval(m.dueInterval)
    switch result {
    case .remembered:
      print("✅ [SRS] 記得 - Level \(oldLevel) → \(card.srsLevel), 下次複習: \(card.dueAt)")
    case .forgotten:
      print("❌ [SRS] 不記得 - Level \(oldLevel) → \(card.srsLevel), 10 分鐘後再複習")
    }
    card.lastReviewedAt = now
    
    // 更新到期卡片數量到 App Group
    if let context = card.modelContext {
      updateDueCountToAppGroup(context: context)
    }
  }
  
  // MARK: - 更新到期卡片數量到 App Group
  // 計算並儲存今日到期卡片數量，供 Widget 使用
  // 確保在主線程執行，避免線程安全問題
  func updateDueCountToAppGroup(context: ModelContext) {
    // 確保在主線程執行 UserDefaults 操作
    if Thread.isMainThread {
      let dueCount = getDueCards(now: Date(), context: context).count
      userDefaults.set(dueCount, forKey: AppGroup.Keys.todayDueCount)
      userDefaults.synchronize() // 確保立即寫入
      
      // 使用 WidgetReloader 統一管理刷新（帶防抖機制）
      WidgetReloader.reloadAll()
    } else {
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        let dueCount = self.getDueCards(now: Date(), context: context).count
        self.userDefaults.set(dueCount, forKey: AppGroup.Keys.todayDueCount)
        self.userDefaults.synchronize()
        WidgetReloader.reloadAll()
      }
    }
  }
  
  // MARK: - 取得今日到期卡片數量
  func getTodayDueCount(context: ModelContext) -> Int {
    return getDueCards(now: Date(), context: context).count
  }
}
