// StudyLog+Streak.swift
// 共用：從今天往前計算連續學習天數

import Foundation
import SwiftData

extension Array where Element == StudyLog {
  /// 從今天開始往前計算連續學習天數（同一天多筆記錄只算一天）
  func currentStreak() -> Int {
    guard !isEmpty else { return 0 }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var studyDates = Set<Date>()
    for log in self {
      studyDates.insert(calendar.startOfDay(for: log.date))
    }
    var streak = 0
    var currentDate = today
    while studyDates.contains(currentDate) {
      streak += 1
      guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
      currentDate = previousDate
    }
    return streak
  }
}
