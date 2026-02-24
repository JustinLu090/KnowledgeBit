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
  private func intervalForLevel(_ level: Int) -> TimeInterval {
    switch level {
    case 0: return 10 * 60        // 10 分鐘
    case 1: return 1 * 24 * 60 * 60   // 1 天
    case 2: return 3 * 24 * 60 * 60   // 3 天
    case 3: return 7 * 24 * 60 * 60   // 7 天
    case 4: return 14 * 24 * 60 * 60  // 14 天
    case 5: return 30 * 24 * 60 * 60  // 30 天
    default:
      let extraDays = (level - 5) * 30
      return TimeInterval(extraDays * 24 * 60 * 60)
    }
  }

  // MARK: - 查詢到期卡片
  // ✅ 只取得 QA 卡片（語錄卡片不進 SRS）
  func getDueCards(now: Date = Date(), context: ModelContext) -> [Card] {
    let qaRaw = CardKind.qa.rawValue

    let descriptor = FetchDescriptor<Card>(
      predicate: #Predicate<Card> { card in
        card.kindRaw == qaRaw && card.dueAt <= now
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
  func applyReview(card: Card, result: ReviewResult, now: Date = Date()) {
    // ✅ 防呆：語錄卡片不應該被複習
    guard card.kind == .qa else { return }

    let oldLevel = card.srsLevel

    switch result {
    case .remembered:
      card.srsLevel += 1
      card.correctStreak += 1
      card.dueAt = now.addingTimeInterval(intervalForLevel(card.srsLevel))
      print("✅ [SRS] 記得 - Level \(oldLevel) → \(card.srsLevel), 下次複習: \(card.dueAt)")

    case .forgotten:
      card.srsLevel = 0
      card.correctStreak = 0
      card.dueAt = now.addingTimeInterval(intervalForLevel(0))
      print("❌ [SRS] 不記得 - Level \(oldLevel) → 0, 10 分鐘後再複習")
    }

    card.lastReviewedAt = now

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
#endif
  }

  // MARK: - 取得今日到期卡片數量
  func getTodayDueCount(context: ModelContext) -> Int {
    return getDueCards(now: Date(), context: context).count
  }
}

// MARK: - ReviewResult
enum ReviewResult {
  case remembered
  case forgotten
}
