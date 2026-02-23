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
      
      // 嘗試刪除舊資料庫檔案（SwiftData 可能使用不同的檔案名稱）
      if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
        let fileManager = FileManager.default
        let possibleDBFiles = [
          "default.store",
          "default.sqlite",
          "default.sqlite-wal",
          "default.sqlite-shm"
        ]
        
        var deletedAny = false
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
        if let (code, _) = Self.parseInviteURL(url) {
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
        dailyQuestService.refreshIfNewDay()
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
      }
    }
  }
}

// MARK: - 邀請連結解析（供 onOpenURL 使用）
private extension KnowledgeBitApp {
  /// 解析邀請連結，回傳 (invite_code, displayName 可選)。支援 https 邀請頁（與 InviteConstants.baseURL 同 host）與 knowledgebit://join/XXX
  static func parseInviteURL(_ url: URL) -> (code: String, displayName: String?)? {
    let scheme = url.scheme?.lowercased()
    let host = url.host?.lowercased()
    let path = url.path
    let expectedHost = URL(string: InviteConstants.baseURL)?.host?.lowercased()
    let isWeb = scheme == "https" && host == expectedHost && path.hasPrefix("/join/")
    let isAppScheme = scheme == InviteConstants.urlScheme && host == "join"
    guard isWeb || isAppScheme else { return nil }
    let code = url.lastPathComponent.trimmingCharacters(in: .whitespaces)
    guard !code.isEmpty, code.count <= 32 else { return nil }
    return (code, nil)
  }
}
