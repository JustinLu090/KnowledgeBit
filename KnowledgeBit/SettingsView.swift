import SwiftUI

struct SettingsView: View {
  @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
  @AppStorage("notificationTime") private var notificationTime = Date() // 預設可能是現在時間
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("提醒設定")) {
          // 1. 開關
          Toggle("每日測驗提醒", isOn: $isNotificationEnabled)
            .onChange(of: isNotificationEnabled) { _, newValue in
              if newValue {
                // 開啟時請求權限
                NotificationManager.shared.requestPermission()
                scheduleNotification()
              } else {
                // 關閉時取消通知
                NotificationManager.shared.cancelAllNotifications()
              }
            }

          // 2. 時間選擇器 (只有開啟時才顯示)
          if isNotificationEnabled {
            DatePicker("提醒時間", selection: $notificationTime, displayedComponents: .hourAndMinute)
              .onChange(of: notificationTime) { _, _ in
                scheduleNotification()
              }
          }
        }

        Section(header: Text("關於")) {
          Text("KnowledgeBit v1.0")
          Text("Designed by You")
        }
      }
      .navigationTitle("設定")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { dismiss() }
        }
      }
    }
  }

  // 輔助函式：呼叫 Manager 進行排程
  private func scheduleNotification() {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: notificationTime)
    let minute = calendar.component(.minute, from: notificationTime)

    NotificationManager.shared.scheduleDailyReminder(hour: hour, minute: minute)
  }
}
