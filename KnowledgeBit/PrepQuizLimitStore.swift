// PrepQuizLimitStore.swift
// 每位使用者每日準備期測驗次數限制（預設上限 5 次）

import Foundation

@MainActor
final class PrepQuizLimitStore {
  private let defaults = AppGroup.sharedUserDefaults()
  private let baseKey = "prep_quiz_count"

  private func dayString(_ date: Date) -> String {
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = .current
    df.dateFormat = "yyyy-MM-dd"
    return df.string(from: date)
  }

  private func key(for userId: UUID, date: Date) -> String {
    "\(baseKey).\(userId.uuidString).\(dayString(date))"
  }

  func todayCount(for userId: UUID, now: Date = Date()) -> Int {
    defaults?.integer(forKey: key(for: userId, date: now)) ?? 0
  }

  func remaining(for userId: UUID, maxPerDay: Int = 5, now: Date = Date()) -> Int {
    max(0, maxPerDay - todayCount(for: userId, now: now))
  }

  func canStart(for userId: UUID, maxPerDay: Int = 5, now: Date = Date()) -> Bool {
    todayCount(for: userId, now: now) < maxPerDay
  }

  /// 在開始測驗前呼叫，若達上限則不會增加
  @discardableResult
  func incrementIfAllowed(for userId: UUID, maxPerDay: Int = 5, now: Date = Date()) -> Bool {
    let k = key(for: userId, date: now)
    let current = defaults?.integer(forKey: k) ?? 0
    guard current < maxPerDay else { return false }
    defaults?.set(current + 1, forKey: k)
    defaults?.synchronize()
    return true
  }
}
