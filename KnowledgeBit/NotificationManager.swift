import Foundation
import UserNotifications

class NotificationManager {
  static let shared = NotificationManager() // 單例模式

  // 1. 請求權限
  func requestPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if granted {
        print("通知權限已開通")
      } else if let error = error {
        print("通知權限錯誤: \(error.localizedDescription)")
      }
    }
  }

  func scheduleDailyReminder(hour: Int, minute: Int) {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

    let content = UNMutableNotificationContent()
    content.title = "每日知識驗收"
    content.body = "今天的 Widget 內容記住了嗎？花 1 分鐘來測驗一下吧！"
    content.sound = .default

    var dateComponents = DateComponents()
    dateComponents.hour = hour
    dateComponents.minute = minute

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

    let request = UNNotificationRequest(identifier: "daily_quiz_reminder", content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("無法加入通知: \(error)")
      } else {
        print("已設定每日 \(hour):\(minute) 的提醒")
      }
    }
  }

  func cancelAllNotifications() {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    print("已取消所有通知")
  }
}
