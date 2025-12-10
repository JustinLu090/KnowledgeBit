// WeeklyCalendarView.swift
// Weekly calendar strip showing 7 days of study activity

import SwiftUI
import Foundation

// MARK: - Intensity Level

/// Visual intensity level for study activity (GitHub-style contribution levels)
enum IntensityLevel: Int, CaseIterable {
  case none = 0   // 0 cards
  case low = 1    // 1–2 cards
  case medium = 2 // 3–5 cards
  case high = 3   // 6–9 cards
  case max = 4    // 10+ cards
  
  /// Map total cards reviewed to intensity level
  static func from(cardCount: Int) -> IntensityLevel {
    switch cardCount {
    case 0:
      return .none
    case 1...2:
      return .low
    case 3...5:
      return .medium
    case 6...9:
      return .high
    default:
      return .max
    }
  }
  
  /// Get color for this intensity level
  var color: Color {
    switch self {
    case .none:
      return Color(uiColor: .systemGray5)
    case .low:
      return Color.accentColor.opacity(0.3)
    case .medium:
      return Color.accentColor.opacity(0.5)
    case .high:
      return Color.accentColor.opacity(0.7)
    case .max:
      return Color.accentColor.opacity(1.0)
    }
  }
}

// MARK: - Day Study Summary

/// Represents one day's study activity summary
struct DayStudySummary: Identifiable {
  let id = UUID()
  let date: Date
  let totalCards: Int
  let didStudy: Bool
  let isToday: Bool
  let intensity: IntensityLevel
  
  init(date: Date, totalCards: Int, isToday: Bool) {
    self.date = date
    self.totalCards = totalCards
    self.didStudy = totalCards > 0
    self.isToday = isToday
    self.intensity = IntensityLevel.from(cardCount: totalCards)
  }
}

// MARK: - Date Helpers

extension Date {
  /// Get the start of day for this date
  var startOfDay: Date {
    Calendar.current.startOfDay(for: self)
  }
  
  /// Get short weekday label (e.g., "Mon", "Tue")
  var shortWeekdayLabel: String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "E"
    return formatter.string(from: self)
  }
  
  /// Get day number (e.g., "1", "15")
  var dayNumber: String {
    let formatter = DateFormatter()
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
              // Highlight today with a border
              Circle()
                .stroke(Color.accentColor, lineWidth: day.isToday ? 2 : 0)
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

