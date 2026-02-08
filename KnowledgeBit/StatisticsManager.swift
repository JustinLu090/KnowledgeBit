// StatisticsManager.swift
// 從打卡紀錄與任務系統彙整本週每日 EXP、總學習時長、單字複習平均正確率

import Foundation
import SwiftData

/// 本週某一天的 EXP 數據（供圖表使用）
struct DayExpItem: Identifiable {
  var id: Date { date }
  let date: Date
  let exp: Int
  let dayLabel: String  // 例：「週一」「2/3」
}

final class StatisticsManager {
  static let shared = StatisticsManager()
  
  private let userDefaults: UserDefaults
  private let lastFlushDateKey = "statistics_last_flush_date"
  
  private init() {
    guard let shared = UserDefaults(suiteName: AppGroup.identifier) else {
      fatalError("App Group UserDefaults not available")
    }
    self.userDefaults = shared
  }
  
  private var calendar: Calendar { .current }
  
  /// 今日 0 點
  private func todayStart() -> Date {
    calendar.startOfDay(for: Date())
  }
  
  /// 本週第一天（週日為第一天）
  private func weekStart(for date: Date) -> Date {
    let weekday = calendar.component(.weekday, from: date)
    let offset = weekday - 1
    return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date)) ?? date
  }
  
  /// 若已跨日，將「昨日」的 EXP/學習時長寫入 DailyStats（僅當上次 flush 是昨天時），再呼叫 refreshIfNewDay
  func flushYesterdayIfNeeded(modelContext: ModelContext, dailyQuestService: DailyQuestService) {
    let today = todayStart()
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
    let lastFlush = userDefaults.object(forKey: lastFlushDateKey) as? Date

    if let last = lastFlush, calendar.isDate(last, inSameDayAs: today) {
      return
    }
    // 僅當「上次 flush 日」是昨天時，才把目前 UserDefaults 的數值視為昨日並寫入
    if let last = lastFlush, calendar.isDate(last, inSameDayAs: yesterday) {
      let exp = dailyQuestService.todayExpGained
      let minutes = dailyQuestService.todayStudyMinutes
      let descriptor = FetchDescriptor<DailyStats>(
        predicate: #Predicate<DailyStats> { $0.date == yesterday },
        sortBy: [SortDescriptor(\.date)]
      )
      let existing = (try? modelContext.fetch(descriptor)) ?? []
      if existing.isEmpty {
        modelContext.insert(DailyStats(date: yesterday, expGained: exp, studyMinutes: minutes))
        try? modelContext.save()
      }
    }

    dailyQuestService.refreshIfNewDay()
    userDefaults.set(today, forKey: lastFlushDateKey)
  }
  
  /// 本週每日的 EXP 獲得總量（含今天，今天從 DailyQuestService 取）
  func weeklyDailyExp(modelContext: ModelContext, dailyQuestService: DailyQuestService) -> [DayExpItem] {
    let start = weekStart(for: Date())
    var items: [DayExpItem] = []
    let weekdaySymbols = calendar.shortWeekdaySymbols
    for dayOffset in 0..<7 {
      guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
      let dayStart = calendar.startOfDay(for: day)
      let isToday = calendar.isDate(dayStart, inSameDayAs: todayStart())
      let exp: Int
      if isToday {
        exp = dailyQuestService.todayExpGained
      } else {
        let descriptor = FetchDescriptor<DailyStats>(
          predicate: #Predicate<DailyStats> { $0.date == dayStart },
          sortBy: [SortDescriptor(\.date)]
        )
        let stats = (try? modelContext.fetch(descriptor))?.first
        exp = stats?.expGained ?? 0
      }
      let weekdayIndex = calendar.component(.weekday, from: day) - 1
      let dayLabel = weekdaySymbols[weekdayIndex]
      items.append(DayExpItem(date: dayStart, exp: exp, dayLabel: dayLabel))
    }
    return items
  }
  
  /// 本週總學習時長（分鐘）
  func weeklyTotalStudyMinutes(modelContext: ModelContext, dailyQuestService: DailyQuestService) -> Int {
    let start = weekStart(for: Date())
    var total = 0
    let today = todayStart()
    for dayOffset in 0..<7 {
      guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
      let dayStart = calendar.startOfDay(for: day)
      if calendar.isDate(dayStart, inSameDayAs: today) {
        total += dailyQuestService.todayStudyMinutes
      } else {
        let descriptor = FetchDescriptor<DailyStats>(
          predicate: #Predicate<DailyStats> { $0.date == dayStart },
          sortBy: [SortDescriptor(\.date)]
        )
        if let stats = (try? modelContext.fetch(descriptor))?.first {
          total += stats.studyMinutes
        }
      }
    }
    return total
  }
  
  /// 本週單字複習平均正確率（0~1，無資料時為 nil）
  func weeklyAverageAccuracy(modelContext: ModelContext) -> Double? {
    let start = weekStart(for: Date())
    guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
    var descriptor = FetchDescriptor<StudyLog>(
      sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    descriptor.predicate = #Predicate<StudyLog> { log in
      log.date >= start && log.date < end && log.totalCards > 0
    }
    let logs = (try? modelContext.fetch(descriptor)) ?? []
    let totalCorrect = logs.reduce(0) { $0 + $1.cardsReviewed }
    let totalCards = logs.reduce(0) { $0 + $1.totalCards }
    guard totalCards > 0 else { return nil }
    return Double(totalCorrect) / Double(totalCards)
  }
}
