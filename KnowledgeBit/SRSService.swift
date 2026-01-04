// SRSService.swift
// 處理 SRS (Spaced Repetition System) 相關邏輯

import Foundation
import SwiftData
#if os(iOS)
import WidgetKit
#endif

class SRSService {
  private let userDefaults: UserDefaults
  
  init() {
    guard let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
      fatalError("無法取得 App Group UserDefaults")
    }
    self.userDefaults = sharedDefaults
  }
  
  // MARK: - SRS 間隔設定
  // 根據 srsLevel 返回下次複習的間隔時間
  private func intervalForLevel(_ level: Int) -> TimeInterval {
    switch level {
    case 0: return 10 * 60        // 10 分鐘
    case 1: return 1 * 24 * 60 * 60   // 1 天
    case 2: return 3 * 24 * 60 * 60   // 3 天
    case 3: return 7 * 24 * 60 * 60   // 7 天
    case 4: return 14 * 24 * 60 * 60  // 14 天
    case 5: return 30 * 24 * 60 * 60  // 30 天
    default:
      // 超過 5 級後，每級增加 30 天
      let extraDays = (level - 5) * 30
      return TimeInterval(extraDays * 24 * 60 * 60)
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
    
    switch result {
    case .remembered:
      // 記得：等級 +1
      card.srsLevel += 1
      card.correctStreak += 1
      card.dueAt = now.addingTimeInterval(intervalForLevel(card.srsLevel))
      print("✅ [SRS] 記得 - Level \(oldLevel) → \(card.srsLevel), 下次複習: \(card.dueAt)")
      
    case .forgotten:
      // 不記得：等級歸 0，10 分鐘後再複習
      card.srsLevel = 0
      card.correctStreak = 0
      card.dueAt = now.addingTimeInterval(intervalForLevel(0))  // 10 分鐘
      print("❌ [SRS] 不記得 - Level \(oldLevel) → 0, 10 分鐘後再複習")
    }
    
    card.lastReviewedAt = now
    
    // 更新到期卡片數量到 App Group
    if let context = card.modelContext {
      updateDueCountToAppGroup(context: context)
    }
  }
  
  // MARK: - 更新到期卡片數量到 App Group
  // 計算並儲存今日到期卡片數量，供 Widget 使用
  func updateDueCountToAppGroup(context: ModelContext) {
    let dueCount = getDueCards(now: Date(), context: context).count
    userDefaults.set(dueCount, forKey: "today_due_count")
    
    // 重新載入 Widget timeline
    #if os(iOS)
    if #available(iOS 16.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
    #endif
    
    print("📊 [SRS] 更新到期卡片數: \(dueCount)")
  }
  
  // MARK: - 取得今日到期卡片數量
  func getTodayDueCount(context: ModelContext) -> Int {
    return getDueCards(now: Date(), context: context).count
  }
}

// MARK: - ReviewResult
enum ReviewResult {
  case remembered  // 記得
  case forgotten   // 不記得
}
