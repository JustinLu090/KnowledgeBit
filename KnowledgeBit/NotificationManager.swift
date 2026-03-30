// NotificationManager.swift
// 通知管理：每日學習提醒、到期卡片提醒、連續學習提醒

import Foundation
import UserNotifications
import os

final class NotificationManager {
  static let shared = NotificationManager()
  private init() {}

  // MARK: - Notification IDs

  private enum ID {
    static let dailyStudy   = "daily_study_reminder"
    static let dueCards     = "due_cards_reminder"
    static let streakRisk   = "streak_risk_reminder"
  }

  // MARK: - Permission

  func requestPermission(completion: ((Bool) -> Void)? = nil) {
    UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        if let error { AppLog.notif.info("⚠️ [Notification] 權限錯誤: \(error.localizedDescription)") }
        completion?(granted)
      }
  }

  func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async { completion(settings.authorizationStatus) }
    }
  }

  // MARK: - Daily Study Reminder

  /// 排程每日學習提醒（含到期卡片數）
  func scheduleDailyStudyReminder(hour: Int, minute: Int, dueCount: Int = 0) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ID.dailyStudy])

    let content = UNMutableNotificationContent()
    content.title = dueCount > 0
      ? "今日有 \(dueCount) 張卡片待複習 📚"
      : "每日學習時間到了！"
    content.body = dueCount > 0
      ? "保持連勝！開始今天的 \(dueCount) 張複習吧"
      : "今天還沒有學習記錄，快來複習一下！"
    content.sound = .default
    content.badge = dueCount > 0 ? 1 : nil

    var components = DateComponents()
    components.hour = hour
    components.minute = minute

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let request = UNNotificationRequest(identifier: ID.dailyStudy, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
      if let error { AppLog.notif.info("⚠️ [Notification] 排程每日提醒失敗: \(error)") }
    }
  }

  /// 舊版 API 相容（SettingsView 呼叫）
  func scheduleDailyReminder(hour: Int, minute: Int) {
    scheduleDailyStudyReminder(hour: hour, minute: minute)
  }

  // MARK: - Streak Risk Reminder

  /// 若使用者今日尚未學習，在傍晚提醒避免斷連
  /// 建議在 App 進入背景時呼叫，排程當天 18:00 提醒（若時間還沒到）
  func scheduleStreakRiskReminder(currentStreak: Int) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ID.streakRisk])
    guard currentStreak > 0 else { return }

    let content = UNMutableNotificationContent()
    content.title = "連續 \(currentStreak) 天的連勝快要斷了！🔥"
    content.body = "今天還沒有學習記錄，快複習一張卡片保住連勝！"
    content.sound = .default

    // 排在今天 18:00，若已過就不排
    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    components.hour = 18
    components.minute = 0
    guard let fireDate = Calendar.current.date(from: components),
          fireDate > Date() else { return }

    let trigger = UNCalendarNotificationTrigger(
      dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
      repeats: false
    )
    let request = UNNotificationRequest(identifier: ID.streakRisk, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
      if let error { AppLog.notif.info("⚠️ [Notification] 排程連勝提醒失敗: \(error)") }
    }
  }

  // MARK: - Badge

  /// 更新 App badge 為到期卡片數
  func updateBadge(dueCount: Int) {
    UNUserNotificationCenter.current().setBadgeCount(dueCount > 0 ? 1 : 0) { error in
      if let error { AppLog.notif.info("⚠️ [Notification] badge 更新失敗: \(error)") }
    }
  }

  // MARK: - Cancel

  func cancelAllNotifications() {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    updateBadge(dueCount: 0)
  }

  func cancelDailyStudyReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ID.dailyStudy])
  }

  func cancelStreakRiskReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ID.streakRisk])
  }
}
