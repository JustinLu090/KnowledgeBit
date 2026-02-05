// StudyHeatmapView.swift
// LeetCode-style contribution heatmap with precise date alignment
// Each month's first day aligns to its actual weekday

import SwiftUI
import SwiftData
import Foundation

// MARK: - Heatmap Data Model

/// Represents one day's study activity for the heatmap
struct HeatmapDay: Identifiable {
  let id = UUID()
  let date: Date
  let count: Int  // Number of quizzes/tests taken on this day
  let level: HeatmapLevel
  let isEmpty: Bool  // True if this is a placeholder cell
  
  init(date: Date, count: Int, isEmpty: Bool = false) {
    self.date = date
    self.count = count
    self.level = HeatmapLevel.from(count: count)
    self.isEmpty = isEmpty
  }
}

/// Represents a month block with its weeks and days
struct MonthBlock: Identifiable {
  let id = UUID()
  let monthName: String
  let monthIndex: Int
  let year: Int
  let weeks: [[HeatmapDay]]  // Each inner array represents a week (7 days)
}

// MARK: - Heatmap Level (Blue Scale)

/// Visual intensity level based on quiz count (blue scale)
enum HeatmapLevel: Int, CaseIterable {
  case level0 = 0  // 0 times
  case level1 = 1  // 1-2 times
  case level2 = 2  // 3-5 times
  case level3 = 3  // 6-9 times
  case level4 = 4  // 10+ times
  
  /// Map quiz count to intensity level
  static func from(count: Int) -> HeatmapLevel {
    switch count {
    case 0:
      return .level0
    case 1...2:
      return .level1
    case 3...5:
      return .level2
    case 6...9:
      return .level3
    default:
      return .level4
    }
  }
  
  /// Get color for this intensity level (blue scale)
  func color() -> Color {
    switch self {
    case .level0:
      return Color(.systemGray6)
    case .level1:
      return Color.blue.opacity(0.2)
    case .level2:
      return Color.blue.opacity(0.5)
    case .level3:
      return Color.blue.opacity(0.8)
    case .level4:
      return Color.blue
    }
  }
}

// MARK: - Year Selection

enum YearSelection: String, CaseIterable {
  case lastYear = "Last Year"
  case current = "Current"
  case year2025 = "2025"
  case year2026 = "2026"
  case year2027 = "2027"
  
  var displayName: String {
    return self.rawValue
  }
  
  /// Get the start date for the selected year
  func startDate() -> Date {
    let calendar = Calendar.current
    let now = Date()
    
    switch self {
    case .current:
      // Current year from Jan 1
      let year = calendar.component(.year, from: now)
      return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
    case .lastYear:
      // Past 365 days from today
      return calendar.date(byAdding: .day, value: -364, to: now) ?? now
    case .year2025:
      return calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? now
    case .year2026:
      return calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? now
    case .year2027:
      return calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)) ?? now
    }
  }
  
  /// Get the end date for the selected year
  func endDate() -> Date {
    let calendar = Calendar.current
    let now = Date()
    
    switch self {
    case .current:
      // End of current year
      let year = calendar.component(.year, from: now)
      return calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? now
    case .lastYear:
      return now
    case .year2025, .year2026, .year2027:
      // End of the year
      let year = calendar.component(.year, from: startDate())
      return calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? now
    }
  }
}

// MARK: - Study Heatmap View

struct StudyHeatmapView: View {
  @Query(sort: \StudyLog.date, order: .reverse) private var logs: [StudyLog]
  @Environment(\.modelContext) private var modelContext
  
  @State private var selectedDay: HeatmapDay?
  @State private var selectedYear: YearSelection = .lastYear
  @State private var showingDeleteAlert = false
  
  // Grid configuration
  private let cellSize: CGFloat = 12
  private let cellGap: CGFloat = 2
  private let monthGap: CGFloat = 8  // Gap between month blocks
  
  var body: some View {
    VStack(spacing: 16) {
      // Header: Statistics with year selector and delete button
      headerSection
      
      // Heatmap Grid with month blocks
      heatmapGrid
    }
    .padding(.vertical, 20)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
    .alert("刪除所有學習記錄", isPresented: $showingDeleteAlert) {
      Button("取消", role: .cancel) { }
      Button("刪除", role: .destructive) {
        deleteAllStudyLogs()
      }
    } message: {
      Text("確定要刪除所有學習記錄嗎？此操作無法復原。")
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    VStack(spacing: 12) {
      // Top row: Submissions count (left) and Year selector + Delete button (right)
      HStack {
        // Left side: Submissions count
        HStack(spacing: 4) {
          Text("\(totalSubmissions)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
          Text("submissions in the past year")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        // Right side: Year selector and Delete button
        HStack(spacing: 8) {
          // Year selector menu
          Menu {
            ForEach([YearSelection.lastYear, YearSelection.current], id: \.self) { year in
              Button(action: {
                selectedYear = year
              }) {
                HStack {
                  Text(year.displayName)
                  if selectedYear == year {
                    Image(systemName: "checkmark")
                  }
                }
              }
            }
          } label: {
            HStack(spacing: 4) {
              Text(selectedYear.displayName)
                .font(.system(size: 13, weight: .medium))
              Image(systemName: "chevron.down")
                .font(.system(size: 10))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(6)
          }
          
          // Delete button
          Button(action: {
            showingDeleteAlert = true
          }) {
            Image(systemName: "trash")
              .font(.system(size: 13))
              .foregroundStyle(.red)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color(.systemGray6))
              .cornerRadius(6)
          }
        }
      }
      
      // Bottom row: Active days and Max streak (right aligned)
      HStack {
        Spacer()
        Text("Total active days: \(activeDaysCount)")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
        Text("|")
          .font(.system(size: 13))
          .foregroundStyle(.tertiary)
        Text("Max streak: \(maxStreak)")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 20)
  }
  
  // MARK: - Heatmap Grid
  
  private var heatmapGrid: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: monthGap) {
          ForEach(monthBlocks) { monthBlock in
            monthBlockView(monthBlock: monthBlock)
              .id(monthBlock.id)
          }
        }
        .padding(.horizontal, 20)
        .padding(.trailing, 20)
      }
      .onAppear {
        scrollToLatest(proxy: proxy)
      }
      .onChange(of: selectedYear) { _, _ in
        // Scroll to latest when year changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          scrollToLatest(proxy: proxy)
        }
      }
    }
    .padding(.horizontal, 20)
  }
  
  // MARK: - Month Block View
  
  private func monthBlockView(monthBlock: MonthBlock) -> some View {
    VStack(spacing: 4) {
      // Weeks grid (each column is a week)
      HStack(alignment: .top, spacing: cellGap) {
        ForEach(Array(monthBlock.weeks.enumerated()), id: \.offset) { weekIndex, week in
          VStack(spacing: cellGap) {
            ForEach(week) { day in
              heatmapCell(day: day)
            }
          }
        }
      }
      
      // Month label below the block (centered)
      Text(monthBlock.monthName)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }
  }
  
  // MARK: - Heatmap Cell
  
  private func heatmapCell(day: HeatmapDay) -> some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 2)
        .fill(day.level.color())
        .frame(width: cellSize, height: cellSize)
      
      // Tooltip overlay (positioned above the cell)
      if selectedDay?.id == day.id && !day.isEmpty {
        tooltipView(day: day)
          .offset(y: -cellSize - 8)
      }
    }
    .onTapGesture {
      // Only allow tap on non-empty cells
      guard !day.isEmpty else { return }
      
      HapticFeedbackHelper.light()
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        if selectedDay?.id == day.id {
          selectedDay = nil
        } else {
          selectedDay = day
        }
      }
    }
  }
  
  // MARK: - Tooltip View
  
  private func tooltipView(day: HeatmapDay) -> some View {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let dateString = formatter.string(from: day.date)
    
    return VStack(spacing: 0) {
      Text("\(dateString): \(day.count) 次測驗")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
      
      // Arrow pointing down
      Triangle()
        .fill(Color(.systemBackground))
        .frame(width: 6, height: 4)
        .offset(y: -1)
    }
  }
  
  // MARK: - Triangle Shape (for tooltip arrow)
  
  struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
      var path = Path()
      path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
      path.closeSubpath()
      return path
    }
  }
  
  // MARK: - Data Processing
  
  /// Count study records for a specific date
  /// Efficient helper function to count quizzes/tests for a given date
  func countForDate(_ date: Date) -> Int {
    let calendar = Calendar.current
    let targetDate = calendar.startOfDay(for: date)
    
    return logs
      .filter { log in
        let logDate = calendar.startOfDay(for: log.date)
        return logDate == targetDate
      }
      .reduce(0) { $0 + $1.cardsReviewed }
  }
  
  // MARK: - Computed Properties
  
  /// Generate heatmap data for the selected year
  private var heatmapData: [HeatmapDay] {
    let calendar = Calendar.current
    let startDate = selectedYear.startDate()
    let endDate = selectedYear.endDate()
    
    // Generate days of data for the selected period
    var days: [HeatmapDay] = []
    var currentDate = calendar.startOfDay(for: startDate)
    let end = calendar.startOfDay(for: endDate)
    
    while currentDate <= end {
      let count = countForDate(currentDate)
      days.append(HeatmapDay(date: currentDate, count: count))
      
      guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
        break
      }
      currentDate = nextDate
    }
    
    return days
  }
  
  /// Generate calendar data organized by months
  /// Uses precise date calculation with Calendar.range and firstDayWeekday
  func generateCalendarData() -> [MonthBlock] {
    let calendar = Calendar.current
    var monthBlocks: [MonthBlock] = []
    
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "MMM"
    
    // Group days by month
    var currentMonth: Int? = nil
    var currentYear: Int? = nil
    var currentMonthDays: [HeatmapDay] = []
    
    for day in heatmapData {
      let month = calendar.component(.month, from: day.date)
      let year = calendar.component(.year, from: day.date)
      
      if currentMonth != month {
        // Save previous month if exists
        if let prevMonth = currentMonth, let prevYear = currentYear, !currentMonthDays.isEmpty {
          let weeks = organizeDaysIntoWeeks(days: currentMonthDays, calendar: calendar)
          let monthName = formatter.string(from: calendar.date(from: DateComponents(year: prevYear, month: prevMonth)) ?? Date())
          monthBlocks.append(MonthBlock(
            monthName: monthName,
            monthIndex: prevMonth,
            year: prevYear,
            weeks: weeks
          ))
        }
        
        // Start new month
        currentMonth = month
        currentYear = year
        currentMonthDays = [day]
      } else {
        currentMonthDays.append(day)
      }
    }
    
    // Add the last month
    if let lastMonth = currentMonth, let lastYear = currentYear, !currentMonthDays.isEmpty {
      let weeks = organizeDaysIntoWeeks(days: currentMonthDays, calendar: calendar)
      let monthName = formatter.string(from: calendar.date(from: DateComponents(year: lastYear, month: lastMonth)) ?? Date())
      monthBlocks.append(MonthBlock(
        monthName: monthName,
        monthIndex: lastMonth,
        year: lastYear,
        weeks: weeks
      ))
    }
    
    return monthBlocks
  }
  
  /// Organize days into weeks (7 days per week)
  /// Uses Calendar.range to get month days and firstDayWeekday for precise alignment
  /// Each month's first day aligns to its actual weekday
  private func organizeDaysIntoWeeks(days: [HeatmapDay], calendar: Calendar) -> [[HeatmapDay]] {
    guard !days.isEmpty else { return [] }
    
    // Get the first day of the month
    let firstDay = days.first!
    let firstDayDate = firstDay.date
    
    // Get the weekday of the first day (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    let firstDayWeekday = calendar.component(.weekday, from: firstDayDate)
    
    // Calculate offset: if 1st is Wednesday (weekday = 4), we need 3 empty cells
    // Offset = firstDayWeekday - 1 (Sunday = 0 offset, Monday = 1, ..., Saturday = 6)
    let offset = firstDayWeekday - 1
    
    var weeks: [[HeatmapDay]] = []
    var currentWeek: [HeatmapDay] = []
    
    // Add empty placeholder cells at the beginning if needed
    if offset > 0 {
      for i in 0..<offset {
        // Create empty placeholder day
        if let placeholderDate = calendar.date(byAdding: .day, value: -(offset - i), to: firstDayDate) {
          currentWeek.append(HeatmapDay(date: placeholderDate, count: 0, isEmpty: true))
        }
      }
    }
    
    // Add all days of the month
    for day in days {
      currentWeek.append(day)
      
      // If we have 7 days, complete the week
      if currentWeek.count == 7 {
        weeks.append(currentWeek)
        currentWeek = []
      }
    }
    
    // Pad the last week if incomplete
    if !currentWeek.isEmpty {
      // Use Calendar.range to get the number of days in the month
      if let monthRange = calendar.range(of: .day, in: .month, for: firstDayDate) {
        let daysInMonth = monthRange.count
        let remainingCells = 7 - currentWeek.count
        
        // Add empty placeholder cells at the end
        for i in 1...remainingCells {
          if let placeholderDate = calendar.date(byAdding: .day, value: daysInMonth + i - 1, to: firstDayDate) {
            currentWeek.append(HeatmapDay(date: placeholderDate, count: 0, isEmpty: true))
          }
        }
      } else {
        // Fallback: use simple date addition
        let lastDay = days.last!
        var dayOffset = 1
        while currentWeek.count < 7 {
          if let placeholderDate = calendar.date(byAdding: .day, value: dayOffset, to: lastDay.date) {
            currentWeek.append(HeatmapDay(date: placeholderDate, count: 0, isEmpty: true))
            dayOffset += 1
          } else {
            break
          }
        }
      }
      
      weeks.append(currentWeek)
    }
    
    return weeks
  }
  
  /// Month blocks organized by months
  private var monthBlocks: [MonthBlock] {
    generateCalendarData()
  }
  
  /// Total submissions in the selected period
  private var totalSubmissions: Int {
    heatmapData.reduce(0) { $0 + $1.count }
  }
  
  /// Number of active days (days with at least one quiz)
  private var activeDaysCount: Int {
    heatmapData.filter { $0.count > 0 }.count
  }
  
  /// Maximum consecutive streak
  private var maxStreak: Int {
    var maxStreak = 0
    var currentStreak = 0
    
    for day in heatmapData {
      if day.count > 0 {
        currentStreak += 1
        maxStreak = max(maxStreak, currentStreak)
      } else {
        currentStreak = 0
      }
    }
    
    return maxStreak
  }
  
  // MARK: - Helper Methods
  
  /// Scroll to the latest date (rightmost position - latest month)
  private func scrollToLatest(proxy: ScrollViewProxy) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      withAnimation(.easeOut(duration: 0.5)) {
        // Scroll to the last month block (rightmost)
        if let lastMonth = monthBlocks.last {
          proxy.scrollTo(lastMonth.id, anchor: UnitPoint.trailing)
        }
      }
    }
  }
  
  /// Delete all study logs
  /// After deletion, @Query will automatically trigger UI update
  private func deleteAllStudyLogs() {
    do {
      let descriptor = FetchDescriptor<StudyLog>()
      let allLogs = try modelContext.fetch(descriptor)
      
      for log in allLogs {
        modelContext.delete(log)
      }
      
      try modelContext.save()
      HapticFeedbackHelper.notification(.success)
      
      // Clear selected day after deletion
      selectedDay = nil
    } catch {
      print("Failed to delete study logs: \(error)")
      HapticFeedbackHelper.notification(.error)
    }
  }
}

// MARK: - Preview

#Preview {
  StudyHeatmapView()
    .padding()
    .background(Color(.systemGroupedBackground))
}
