import SwiftUI
import SwiftData
import Charts

/// Extracted from the old Achievements/Statistics screen for reuse.
struct LearningStatisticsView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var dailyQuestService: DailyQuestService
  @StateObject private var viewModel = StatisticsViewModel()
  @Environment(\.dismiss) private var dismiss

  var showsCloseButton: Bool = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        CompactPageHeader("學習統計") {
          if showsCloseButton {
            Button("關閉") { dismiss() }
              .font(.system(size: 16, weight: .semibold))
          }
        }

        weeklyExpSection
        averageAccuracySection
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
    .background(Color(.systemGroupedBackground))
    .toolbar(.hidden, for: .navigationBar)
    .onAppear {
      StatisticsManager.shared.flushYesterdayIfNeeded(modelContext: modelContext, dailyQuestService: dailyQuestService)
      viewModel.load(modelContext: modelContext, dailyQuestService: dailyQuestService)
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      StatisticsManager.shared.flushYesterdayIfNeeded(modelContext: modelContext, dailyQuestService: dailyQuestService)
      viewModel.load(modelContext: modelContext, dailyQuestService: dailyQuestService)
    }
  }

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

  private var averageAccuracySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("單字複習平均正確率")
        .font(.headline)
        .foregroundStyle(.primary)

      if let percent = viewModel.weeklyAverageAccuracyPercent {
        HStack(spacing: 16) {
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
          Text("本週選擇題測驗平均答對率")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.vertical, 8)
      } else {
        Text("本週尚無選擇題測驗記錄")
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

#Preview {
  NavigationStack {
    LearningStatisticsView(showsCloseButton: true)
      .environmentObject(DailyQuestService())
  }
  .modelContainer(for: [StudyLog.self, DailyStats.self], inMemory: true)
}

