// StreakCardView.swift
// Streak card component extracted from StatsView

import SwiftUI
import SwiftData

struct StreakCardView: View {
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
          Text("\(logs.currentStreak()) 天")
            .font(.title2)
            .bold()
        }
        Spacer()
      }

      // 2. Weekly calendar strip (過去 7 天)
      WeeklyCalendarView(days: weeklySummaries)
    }
    .cardStyle(withShadow: true)
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
