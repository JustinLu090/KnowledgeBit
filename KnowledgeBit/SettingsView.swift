// SettingsView.swift
// 應用程式設定：通知提醒

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
  // MARK: - Stored settings
  @AppStorage("notif_daily_enabled")      private var dailyEnabled      = false
  @AppStorage("notif_daily_hour")         private var dailyHour         = 20
  @AppStorage("notif_daily_minute")       private var dailyMinute       = 0
  @AppStorage("notif_streak_enabled")     private var streakEnabled     = false

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \StudyLog.date, order: .reverse) private var studyLogs: [StudyLog]

  @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
  @State private var showPermissionAlert = false

  // Computed daily time as a Date for DatePicker
  private var dailyTime: Binding<Date> {
    Binding(
      get: {
        var c = DateComponents()
        c.hour   = dailyHour
        c.minute = dailyMinute
        return Calendar.current.date(from: c) ?? Date()
      },
      set: { date in
        dailyHour   = Calendar.current.component(.hour,   from: date)
        dailyMinute = Calendar.current.component(.minute, from: date)
        if dailyEnabled { rescheduleDailyReminder() }
      }
    )
  }

  var body: some View {
    NavigationStack {
      Form {
        // MARK: Permission Banner
        if permissionStatus == .denied {
          Section {
            HStack(spacing: 12) {
              Image(systemName: "bell.slash.fill")
                .foregroundStyle(.red)
              VStack(alignment: .leading, spacing: 4) {
                Text("通知已被關閉")
                  .font(.system(size: 15, weight: .medium))
                Text("請至「設定」→「KnowledgeBit」→「通知」開啟")
                  .font(.system(size: 13))
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Button("前往") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                  UIApplication.shared.open(url)
                }
              }
              .font(.system(size: 14, weight: .medium))
            }
          }
        }

        // MARK: Daily Study Reminder
        Section {
          Toggle("每日學習提醒", isOn: $dailyEnabled)
            .onChange(of: dailyEnabled) { _, enabled in
              if enabled { requestAndScheduleDaily() } else { NotificationManager.shared.cancelDailyStudyReminder() }
            }

          if dailyEnabled {
            DatePicker("提醒時間", selection: dailyTime, displayedComponents: .hourAndMinute)
          }
        } header: {
          Text("📚 學習提醒")
        } footer: {
          Text("在設定時間提醒你複習，並顯示到期卡片數量")
        }

        // MARK: Streak Risk Reminder
        Section {
          Toggle("連勝保護提醒", isOn: $streakEnabled)
            .onChange(of: streakEnabled) { _, enabled in
              if enabled {
                requestAndScheduleStreakReminder()
              } else {
                NotificationManager.shared.cancelStreakRiskReminder()
              }
            }
        } header: {
          Text("🔥 連勝保護")
        } footer: {
          Text("若你今天還沒學習，將在每天 18:00 提醒你保住連勝")
        }
      }
      .navigationTitle("應用程式設定")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { dismiss() }
        }
      }
      .onAppear {
        NotificationManager.shared.checkPermissionStatus { status in
          permissionStatus = status
        }
      }
      .alert("需要通知權限", isPresented: $showPermissionAlert) {
        Button("前往設定") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
        }
        Button("取消", role: .cancel) {}
      } message: {
        Text("請在系統設定中允許 KnowledgeBit 發送通知")
      }
    }
  }

  // MARK: - Helpers

  private func requestAndScheduleDaily() {
    NotificationManager.shared.requestPermission { granted in
      DispatchQueue.main.async {
        if granted {
          rescheduleDailyReminder()
          NotificationManager.shared.checkPermissionStatus { permissionStatus = $0 }
        } else {
          dailyEnabled = false
          showPermissionAlert = true
        }
      }
    }
  }

  private func requestAndScheduleStreakReminder() {
    NotificationManager.shared.requestPermission { granted in
      DispatchQueue.main.async {
        if granted {
          let streak = studyLogs.currentStreak()
          NotificationManager.shared.scheduleStreakRiskReminder(currentStreak: streak)
        } else {
          streakEnabled = false
          showPermissionAlert = true
        }
      }
    }
  }

  private func rescheduleDailyReminder() {
    let dueCount = (try? modelContext.fetch(FetchDescriptor<Card>(
      predicate: #Predicate { $0.dueAt <= Date() }
    )))?.count ?? 0
    NotificationManager.shared.scheduleDailyStudyReminder(
      hour: dailyHour,
      minute: dailyMinute,
      dueCount: dueCount
    )
  }
}
