// WeeklyCalendarView.swift
// Weekly calendar strip showing 7 days of study activity

import SwiftUI
import Foundation

// MARK: - Day Study Summary

/// Represents one day's study activity summary
/// Uses date as stable id to avoid unnecessary view recreation (memory/performance).
struct DayStudySummary: Identifiable {
  var id: TimeInterval { date.timeIntervalSince1970 }
  let date: Date
  let totalCards: Int
  let didStudy: Bool
  let isToday: Bool
  let intensity: StudyIntensityLevel
  
  init(date: Date, totalCards: Int, isToday: Bool) {
    self.date = date
    self.totalCards = totalCards
    self.didStudy = totalCards > 0
    self.isToday = isToday
    self.intensity = StudyIntensityLevel.from(cardCount: totalCards)
  }
}

// MARK: - Date Helpers

extension Date {
  /// Get the start of day for this date
  var startOfDay: Date {
    Calendar.current.startOfDay(for: self)
  }
  
  /// Get short weekday label (e.g., "Mon", "Tue") in user's locale and timezone
  var shortWeekdayLabel: String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale.current
    formatter.dateFormat = "E"
    return formatter.string(from: self)
  }
  
  /// Get day number (e.g., "1", "15") in user's locale and timezone
  var dayNumber: String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale.current
    formatter.dateFormat = "d"
    return formatter.string(from: self)
  }
}

// MARK: - Weekly Calendar View

/// SwiftUI view displaying a 7-day weekly calendar strip with study intensity
struct WeeklyCalendarView: View {
  let days: [DayStudySummary]
  
  var body: some View {
    HStack(spacing: 8) {
      ForEach(days) { day in
        VStack(spacing: 4) {
          // Study intensity circle
          Circle()
            .fill(day.intensity.color)
            .frame(width: 26, height: 26)
            .overlay(
              // Highlight today with a blue border
              Circle()
                .stroke(Color.blue, lineWidth: day.isToday ? 2 : 0)
            )
          
          // Weekday label
          Text(day.date.shortWeekdayLabel)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }
}

