// StudyLog+Streak.swift
// 共用：從今天往前計算連續學習天數

import Foundation
import SwiftData

extension Array where Element == StudyLog {
  /// 從「參考日」的當天 0 點開始往前計算連續有打卡的天數（同一天多筆記錄只算一天）
  /// - Parameters:
  ///   - referenceNow: 視為「今天」的時間，預設為現在；測試可傳入固定值以得到穩定結果
  ///   - calendar: 用於切日曆日，預設為目前行事曆
  func currentStreak(referenceNow: Date = Date(), calendar: Calendar = .current) -> Int {
    guard !isEmpty else { return 0 }
    let today = calendar.startOfDay(for: referenceNow)
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
