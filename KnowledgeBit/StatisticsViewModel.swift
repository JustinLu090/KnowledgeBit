// StatisticsViewModel.swift
// 供 SwiftUI 學習統計頁面使用的 ViewModel

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class StatisticsViewModel: ObservableObject {
  @Published private(set) var weeklyDailyExp: [DayExpItem] = []
  @Published private(set) var weeklyTotalStudyMinutes: Int = 0
  @Published private(set) var weeklyAverageAccuracy: Double? = nil
  
  private let manager = StatisticsManager.shared
  
  /// 重新從 StatisticsManager 載入本週數據（需傳入 modelContext 與 dailyQuestService）
  func load(modelContext: ModelContext, dailyQuestService: DailyQuestService) {
    weeklyDailyExp = manager.weeklyDailyExp(modelContext: modelContext, dailyQuestService: dailyQuestService)
    weeklyTotalStudyMinutes = manager.weeklyTotalStudyMinutes(modelContext: modelContext, dailyQuestService: dailyQuestService)
    weeklyAverageAccuracy = manager.weeklyAverageAccuracy(modelContext: modelContext)
  }
  
  /// 平均正確率百分比（0~100），無資料時為 nil
  var weeklyAverageAccuracyPercent: Int? {
    guard let rate = weeklyAverageAccuracy else { return nil }
    return Int(round(rate * 100))
  }
}
