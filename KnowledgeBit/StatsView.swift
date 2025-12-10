import SwiftUI
import SwiftData

struct StatsView: View {
  @Query(sort: \StudyLog.date, order: .reverse) var logs: [StudyLog]

  var body: some View {
    VStack(spacing: 16) {
      // 1. 火焰與連續天數
      HStack {
        Image(systemName: "flame.fill")
          .font(.largeTitle)
          .foregroundStyle(.orange)

        VStack(alignment: .leading) {
          Text("連續學習")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(calculateStreak()) 天")
            .font(.title2)
            .bold()
        }
        Spacer()
      }

      // 2. Weekly calendar strip (過去 7 天)
      WeeklyCalendarView(days: weeklySummaries)
    }
    .padding(20)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
  }

  /// 計算真正的連續學習天數
  /// 從今天開始往前計算，直到遇到沒有學習記錄的日子為止
  func calculateStreak() -> Int {
    guard !logs.isEmpty else { return 0 }
    
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // 將所有學習記錄按日期分組（同一天的多筆記錄只算一天）
    var studyDates = Set<Date>()
    for log in logs {
      let logDate = calendar.startOfDay(for: log.date)
      studyDates.insert(logDate)
    }
    
    // 從今天開始往前計算連續天數
    var streak = 0
    var currentDate = today
    
    while studyDates.contains(currentDate) {
      streak += 1
      // 往前一天
      guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
        break
      }
      currentDate = previousDate
    }
    
    return streak
  }

  /// Generate weekly summaries for the past 7 days (rolling window from 6 days ago to today)
  /// Each summary aggregates StudyLogs for that calendar day
  var weeklySummaries: [DayStudySummary] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // Generate 7 days: from 6 days ago to today (inclusive)
    var summaries: [DayStudySummary] = []
    
    for dayOffset in 0..<7 {
      guard let date = calendar.date(byAdding: .day, value: -6 + dayOffset, to: today) else {
        continue
      }
      
      let dateStart = calendar.startOfDay(for: date)
      let dateEnd = calendar.date(byAdding: .day, value: 1, to: dateStart)!
      
      // Aggregate cardsReviewed for this day
      // Sum all cardsReviewed values from logs on this calendar day
      let totalCards = logs
        .filter { log in
          let logDate = calendar.startOfDay(for: log.date)
          return logDate >= dateStart && logDate < dateEnd
        }
        .reduce(0) { $0 + $1.cardsReviewed }
      
      let isToday = calendar.isDateInToday(date)
      let summary = DayStudySummary(date: date, totalCards: totalCards, isToday: isToday)
      summaries.append(summary)
    }
    
    return summaries
  }
}
