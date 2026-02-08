// StatisticsView.swift
// 學習統計頁面：本週每日 EXP、總學習時長、單字複習平均正確率（Swift Charts）

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var dailyQuestService: DailyQuestService
  @StateObject private var viewModel = StatisticsViewModel()
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        // 本週每日 EXP
        weeklyExpSection
        // 本週總學習時長
        weeklyStudyMinutesSection
        // 單字複習平均正確率
        averageAccuracySection
      }
      .padding(20)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("學習統計")
    .navigationBarTitleDisplayMode(.large)
    .onAppear {
      viewModel.load(modelContext: modelContext, dailyQuestService: dailyQuestService)
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      viewModel.load(modelContext: modelContext, dailyQuestService: dailyQuestService)
    }
  }
  
  // MARK: - 本週每日 EXP 長條圖
  private var weeklyExpSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("本週每日 EXP")
        .font(.headline)
        .foregroundStyle(.primary)
      
      if viewModel.weeklyDailyExp.isEmpty {
        Text("尚無數據")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .frame(height: 120)
      } else {
        Chart(viewModel.weeklyDailyExp) { item in
          BarMark(
            x: .value("日期", item.dayLabel),
            y: .value("EXP", item.exp)
          )
          .foregroundStyle(.blue.gradient)
          .cornerRadius(6)
        }
        .chartYAxis {
          AxisMarks(position: .leading, values: .automatic)
        }
        .frame(height: 200)
      }
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
  }
  
  // MARK: - 本週總學習時長
  private var weeklyStudyMinutesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("本週總學習時長")
        .font(.headline)
        .foregroundStyle(.primary)
      
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Image(systemName: "clock.fill")
          .foregroundStyle(.orange)
        Text("\(viewModel.weeklyTotalStudyMinutes)")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.primary)
        Text("分鐘")
          .font(.title3)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
  }
  
  // MARK: - 單字複習平均正確率
  private var averageAccuracySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("單字複習平均正確率")
        .font(.headline)
        .foregroundStyle(.primary)
      
      if let percent = viewModel.weeklyAverageAccuracyPercent {
        HStack(spacing: 16) {
          // 圓形進度（類似 Gauge）
          ZStack {
            Circle()
              .stroke(Color(.tertiarySystemFill), lineWidth: 10)
              .frame(width: 80, height: 80)
            Circle()
              .trim(from: 0, to: CGFloat(percent) / 100)
              .stroke(
                percent >= 90 ? Color.green : (percent >= 70 ? Color.orange : Color.blue),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
              )
              .frame(width: 80, height: 80)
              .rotationEffect(.degrees(-90))
            Text("\(percent)%")
              .font(.title2.bold())
              .foregroundStyle(.primary)
          }
          Text("本週測驗平均答對率")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.vertical, 8)
      } else {
        Text("本週尚無測驗記錄")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
      }
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
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
