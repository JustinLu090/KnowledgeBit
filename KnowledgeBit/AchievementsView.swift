// AchievementsView.swift
// 成就 Tab：內嵌學習統計頁面

import SwiftUI
import SwiftData

struct AchievementsView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var dailyQuestService: DailyQuestService
  
  var body: some View {
    NavigationStack {
      StatisticsView()
        .environmentObject(dailyQuestService)
        .onAppear {
          // 進入成就頁時確保昨日數據已寫入 DailyStats（若已跨日）
          StatisticsManager.shared.flushYesterdayIfNeeded(modelContext: modelContext, dailyQuestService: dailyQuestService)
        }
    }
  }
}
