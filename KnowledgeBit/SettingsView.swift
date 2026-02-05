import SwiftUI
import SwiftData

struct SettingsView: View {
  @AppStorage("isNotificationEnabled") private var isNotificationEnabled = false
  @AppStorage("notificationTime") private var notificationTime = Date() // 預設可能是現在時間
  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext
  
  @State private var showingDeleteAlert = false

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
        
        Section(header: Text("資料管理")) {
          Button(role: .destructive) {
            showingDeleteAlert = true
          } label: {
            HStack {
              Image(systemName: "trash")
              Text("刪除所有學習記錄")
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
      .alert("刪除所有學習記錄", isPresented: $showingDeleteAlert) {
        Button("取消", role: .cancel) { }
        Button("刪除", role: .destructive) {
          deleteAllStudyLogs()
        }
      } message: {
        Text("確定要刪除所有學習記錄嗎？此操作無法復原。")
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
  
  /// Delete all study logs
  private func deleteAllStudyLogs() {
    do {
      let descriptor = FetchDescriptor<StudyLog>()
      let allLogs = try modelContext.fetch(descriptor)
      
      for log in allLogs {
        modelContext.delete(log)
      }
      
      try modelContext.save()
      HapticFeedbackHelper.notification(.success)
    } catch {
      print("Failed to delete study logs: \(error)")
      HapticFeedbackHelper.notification(.error)
    }
  }
}
