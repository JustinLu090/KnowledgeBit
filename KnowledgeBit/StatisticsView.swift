// StatisticsView.swift
// 學習統計頁面：本週每日 EXP、單字複習平均正確率（Swift Charts）

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
  var body: some View {
    LearningStatisticsView()
  }
}

// MARK: - Preview
#Preview {
  NavigationStack {
    StatisticsView()
      .environmentObject(DailyQuestService())
  }
  .modelContainer(for: [StudyLog.self, DailyStats.self], inMemory: true)
}
