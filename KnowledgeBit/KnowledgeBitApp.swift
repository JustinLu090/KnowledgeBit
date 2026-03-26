// KnowledgeBitApp.swift
import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct KnowledgeBitApp: App {
  // 輔助函數：創建 ModelContainer，處理錯誤和遷移
  private static func createModelContainer() -> ModelContainer {
    let schema = Schema([
      Card.self,
      StudyLog.self,
      DailyStats.self,
      WordSet.self,
      UserProfile.self
    ])
    
    // 嘗試使用 App Group container，如果失敗則回退到默認容器
    let modelConfiguration: ModelConfiguration
    
    // 檢查 App Group 是否可用，並確保目錄存在
    if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
      // App Group 可用，確保 Application Support 目錄存在
      let appSupportURL = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
      let fileManager = FileManager.default
      
      if !fileManager.fileExists(atPath: appSupportURL.path) {
        do {
          try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
          print("✅ Created Application Support directory: \(appSupportURL.path)")
        } catch {
          print("⚠️ Failed to create Application Support directory: \(error.localizedDescription)")
        }
      }
      
      // 使用共享容器
      modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        groupContainer: .identifier(AppGroup.identifier)
      )
      print("✅ Using App Group container: \(AppGroup.identifier)")
    } else {
      // App Group 不可用，使用默認容器（fallback）
      // ⚠️ 注意：這意味著 Widget 將無法訪問數據，請在 Xcode 中配置 App Groups capability
      print("⚠️ App Group not available, using default container. Widget will not work until App Groups is configured in Xcode.")
      modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
      )
    }

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      // 如果是資料庫遷移問題，嘗試刪除舊資料庫並重新創建
      print("⚠️ [Migration] 資料庫遷移失敗，嘗試重新創建資料庫...")
      print("錯誤詳情: \(error.localizedDescription)")
      
      // 嘗試刪除舊資料庫檔案（SwiftData 使用 App Group 時會放在 Library/Application Support/）
      if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
        let fileManager = FileManager.default
        let appSupport = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
        let possibleDBFiles = [
          "default.store",
          "default.sqlite",
          "default.sqlite-wal",
          "default.sqlite-shm"
        ]
        
        var deletedAny = false
        for fileName in possibleDBFiles {
          let dbURL = appSupport.appendingPathComponent(fileName)
          if fileManager.fileExists(atPath: dbURL.path) {
            do {
              try fileManager.removeItem(at: dbURL)
              print("✅ [Migration] 已刪除: \(appSupport.path)/\(fileName)")
              deletedAny = true
            } catch {
              print("⚠️ [Migration] 無法刪除 \(fileName): \(error.localizedDescription)")
            }
          }
        }
        if !deletedAny {
          for fileName in possibleDBFiles {
            let dbURL = groupURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: dbURL.path) {
              do {
                try fileManager.removeItem(at: dbURL)
                print("✅ [Migration] 已刪除: \(fileName)")
                deletedAny = true
              } catch {
                print("⚠️ [Migration] 無法刪除 \(fileName): \(error.localizedDescription)")
              }
            }
          }
        }
        
        if deletedAny {
          print("✅ [Migration] 已清理舊資料庫，將重新創建")
          // 重新嘗試創建
          do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
          } catch {
            // 如果還是失敗，繼續到下面的錯誤處理
            print("❌ [Migration] 重新創建仍然失敗: \(error.localizedDescription)")
          }
        }
      }
      
      // 如果還是失敗，提供詳細錯誤信息
      let errorMessage = """
      ❌ Failed to create ModelContainer:
      Error: \(error.localizedDescription)
      
      Possible causes:
      1. App Groups capability not enabled in Xcode
      2. App Group ID mismatch between code and Xcode settings
      3. Database migration issue
      
      Please check:
      - Xcode > Signing & Capabilities > App Groups
      - Ensure both main app and widget extension have the same App Group ID
      - Try deleting the app and reinstalling to reset the database
      """
      print(errorMessage)
      fatalError(errorMessage)
    }
  }
  
  var sharedModelContainer: ModelContainer = {
    createModelContainer()
  }()

  // 建立 ExperienceStore、TaskService、DailyQuestService、AuthService、邀請 Deep Link 狀態
  @StateObject private var experienceStore = ExperienceStore()
  @StateObject private var taskService = TaskService()
  @StateObject private var dailyQuestService = DailyQuestService()
  @StateObject private var authService = AuthService()
  @StateObject private var pendingInviteStore = PendingInviteStore()
  @StateObject private var pendingBattleOpenStore = PendingBattleOpenStore()
  @StateObject private var battleEnergyStore = BattleEnergyStore()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      Group {
        if authService.isLoggedIn {
          MainTabView()
            .environmentObject(experienceStore)
            .environmentObject(taskService)
            .environmentObject(dailyQuestService)
            .environmentObject(authService)
            .environmentObject(pendingInviteStore)
            .environmentObject(pendingBattleOpenStore)
            .environmentObject(battleEnergyStore)
            .onAppear {
              experienceStore.authService = authService
              // 延遲 0.5 秒再同步，避免 nw_connection 尚未 ready 時發出請求（race condition）
              Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                // 先同步 profile（不立即刷新）
                await authService.syncProfileFromAuthToSupabaseAndAppGroup()
                // 從 Supabase 載入用戶等級與經驗值並同步到 App Group（不立即刷新）
                await experienceStore.loadFromCloud()
                // 所有資料同步完成後，統一觸發一次 Widget 刷新
                await MainActor.run {
                  WidgetReloader.reloadAll()
                }
              }
            }
        } else {
          LoginView()
            .environmentObject(authService)
        }
      }
      .animation(.easeInOut(duration: 0.2), value: authService.isLoggedIn)
      .onOpenURL { url in
        if let wordSetId = DeepLinkParser.parseWordSetURL(url) {
          pendingBattleOpenStore.setWordSetIdToOpen(wordSetId)
          return
        }
        if let wordSetId = DeepLinkParser.parseBattleURL(url) {
          pendingBattleOpenStore.setBattleWordSetIdToOpen(wordSetId)
          return
        }
        if let (code, _) = DeepLinkParser.parseInviteURL(url) {
          Task { @MainActor in
            if authService.isLoggedIn {
              let inviteService = InviteService(authService: authService)
              if let profile = try? await inviteService.fetchProfileByInviteCode(code) {
                pendingInviteStore.setPending(inviteCode: code, inviterDisplayName: profile.displayName)
              } else {
                pendingInviteStore.setPending(inviteCode: code, inviterDisplayName: nil)
              }
            }
          }
          return
        }
        GIDSignIn.sharedInstance.handle(url)
      }
      .onAppear {
        // 設置 ExperienceStore 的 authService 引用（在 App 啟動時設置）
        experienceStore.authService = authService
      }
    }
    .modelContainer(sharedModelContainer)
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        StatisticsManager.shared.flushYesterdayIfNeeded(
          modelContext: sharedModelContainer.mainContext,
          dailyQuestService: dailyQuestService
        )
        // 回到前景時若已登入，延遲同步 profile（避免 nw_connection 未 ready）
        if authService.isLoggedIn {
          Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            // 先同步 profile（不立即刷新）
            await authService.syncProfileFromAuthToSupabaseAndAppGroup()
            // 從 Supabase 載入用戶等級與經驗值並同步到 App Group（不立即刷新）
            await experienceStore.loadFromCloud()
            // 所有資料同步完成後，統一觸發一次 Widget 刷新
            await MainActor.run {
              WidgetReloader.reloadAll()
            }
          }
        }
        // 更新通知 badge 與連勝提醒
        refreshNotifications()
      } else if newPhase == .background {
        // 進入背景時排程連勝風險提醒（今日尚未學習才排）
        refreshStreakReminder()
      }
    }
  }
}

// MARK: - Notification Helpers

private extension KnowledgeBitApp {
  /// 更新 badge 數量，若每日提醒已開啟則重新排程（含最新到期數）
  func refreshNotifications() {
    let dailyEnabled = UserDefaults.standard.bool(forKey: "notif_daily_enabled")
    let now = Date()
    let dueCount = (try? sharedModelContainer.mainContext.fetch(
      FetchDescriptor<Card>(predicate: #Predicate { $0.dueAt <= now })
    ))?.count ?? 0

    NotificationManager.shared.updateBadge(dueCount: dueCount)

    if dailyEnabled {
      let hour   = UserDefaults.standard.integer(forKey: "notif_daily_hour")
      let minute = UserDefaults.standard.integer(forKey: "notif_daily_minute")
      let h = UserDefaults.standard.object(forKey: "notif_daily_hour") == nil ? 20 : hour
      NotificationManager.shared.scheduleDailyStudyReminder(hour: h, minute: minute, dueCount: dueCount)
    }
  }

  /// 若連勝提醒已開啟，排程今日 18:00 提醒（今日已學習則跳過）
  func refreshStreakReminder() {
    guard UserDefaults.standard.bool(forKey: "notif_streak_enabled") else { return }
    let logs = (try? sharedModelContainer.mainContext.fetch(
      FetchDescriptor<StudyLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
    )) ?? []
    let studiedToday = logs.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    guard !studiedToday else { return }
    let streak = logs.currentStreak()
    NotificationManager.shared.scheduleStreakRiskReminder(currentStreak: streak)
  }
}
