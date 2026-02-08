// DailyStats.swift
// 每日統計：用於學習統計頁面之本週每日 EXP、學習時長

import Foundation
import SwiftData

@Model
final class DailyStats {
  var date: Date       // 當日 0 點（calendar startOfDay）
  var expGained: Int   // 當日獲得的 EXP 總量
  var studyMinutes: Int  // 當日學習時長（分鐘）

  init(date: Date, expGained: Int = 0, studyMinutes: Int = 0) {
    self.date = date
    self.expGained = expGained
    self.studyMinutes = studyMinutes
  }
}
