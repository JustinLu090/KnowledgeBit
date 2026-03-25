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
  private let questDateKey = "daily_quest_date"
  
  private init() {
    if let shared = UserDefaults(suiteName: AppGroup.identifier) {
      self.userDefaults = shared
    } else {
      print("⚠️ [Statistics] App Group UserDefaults not available, falling back to standard")
      self.userDefaults = .standard
    }
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
  
  /// 若 DailyQuestService 目前仍持有「昨天」的累積值，先寫入 DailyStats，再呼叫 refreshIfNewDay。
  /// 這比只看 lastFlush 更穩，因為統計頁可能不是每天都被打開。
  func flushYesterdayIfNeeded(modelContext: ModelContext, dailyQuestService: DailyQuestService) {
    let today = todayStart()
    let trackedQuestDate = (userDefaults.object(forKey: questDateKey) as? Date).map { calendar.startOfDay(for: $0) }

    if let trackedDate = trackedQuestDate, trackedDate < today {
      let exp = dailyQuestService.todayExpGained
      let minutes = dailyQuestService.todayStudyMinutes
      let descriptor = FetchDescriptor<DailyStats>(
        predicate: #Predicate<DailyStats> { $0.date == trackedDate },
        sortBy: [SortDescriptor(\.date)]
      )
      let existing: [DailyStats]
      do {
        existing = try modelContext.fetch(descriptor)
      } catch {
        print("❌ [Statistics] flushToSwiftData fetch 失敗: \(error.localizedDescription)")
        existing = []
      }
      if existing.isEmpty {
        modelContext.insert(DailyStats(date: trackedDate, expGained: exp, studyMinutes: minutes))
        do {
          try modelContext.save()
        } catch {
          print("❌ [Statistics] flushToSwiftData save 失敗: \(error.localizedDescription)")
        }
      }
    }

    dailyQuestService.refreshIfNewDay()
    userDefaults.set(today, forKey: lastFlushDateKey)
  }
  
  /// 本週每日的 EXP 獲得總量（含今天，今天從 DailyQuestService 取）
  func weeklyDailyExp(modelContext: ModelContext, dailyQuestService: DailyQuestService) -> [DayExpItem] {
    let start = weekStart(for: Date())
    guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }

    // Fetch once for the whole week, then aggregate in memory to avoid N fetches.
    var weekDescriptor = FetchDescriptor<DailyStats>(
      predicate: #Predicate<DailyStats> { $0.date >= start && $0.date < end },
      sortBy: [SortDescriptor(\.date)]
    )
    weekDescriptor.fetchLimit = 7
    let weekStats: [DailyStats]
    do {
      weekStats = try modelContext.fetch(weekDescriptor)
    } catch {
      print("❌ [Statistics] weeklyDailyExp fetch 失敗: \(error.localizedDescription)")
      weekStats = []
    }
    let statsByDay = Dictionary(uniqueKeysWithValues: weekStats.map { (calendar.startOfDay(for: $0.date), $0) })

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
        exp = statsByDay[dayStart]?.expGained ?? 0
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
    guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return 0 }

    // Fetch once for the whole week.
    var weekDescriptor = FetchDescriptor<DailyStats>(
      predicate: #Predicate<DailyStats> { $0.date >= start && $0.date < end },
      sortBy: [SortDescriptor(\.date)]
    )
    weekDescriptor.fetchLimit = 7
    let weekStats: [DailyStats]
    do {
      weekStats = try modelContext.fetch(weekDescriptor)
    } catch {
      print("❌ [Statistics] weeklyTotalStudyMinutes fetch 失敗: \(error.localizedDescription)")
      weekStats = []
    }
    let minutesByDay = Dictionary(uniqueKeysWithValues: weekStats.map { (calendar.startOfDay(for: $0.date), $0.studyMinutes) })

    var total = 0
    let today = todayStart()
    for dayOffset in 0..<7 {
      guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
      let dayStart = calendar.startOfDay(for: day)
      if calendar.isDate(dayStart, inSameDayAs: today) {
        total += dailyQuestService.todayStudyMinutes
      } else {
        total += minutesByDay[dayStart] ?? 0
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
      log.date >= start
        && log.date < end
        && log.totalCards > 0
        && log.activityType == "multipleChoiceQuiz"
    }
    let logs: [StudyLog]
    do {
      logs = try modelContext.fetch(descriptor)
    } catch {
      print("❌ [Statistics] weeklyAverageAccuracy fetch 失敗: \(error.localizedDescription)")
      logs = []
    }
    let totalCorrect = logs.reduce(0) { $0 + $1.cardsReviewed }
    let totalCards = logs.reduce(0) { $0 + $1.totalCards }
    guard totalCards > 0 else { return nil }
    return Double(totalCorrect) / Double(totalCards)
  }
}
