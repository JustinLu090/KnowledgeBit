// KnowledgeBitApp.swift
import SwiftUI
import SwiftData
import GoogleSignIn
import os

@main
struct KnowledgeBitApp: App {
  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
  }

  // MARK: - SwiftData

  /// 建立本機資料庫；失敗時回傳錯誤訊息字串供畫面顯示（不再 `fatalError`）。
  static func makeModelContainer() -> Result<ModelContainer, ModelStoreError> {
    let schema = Schema([
      Card.self,
      StudyLog.self,
      DailyStats.self,
      WordSet.self,
      UserProfile.self
    ])

    let modelConfiguration: ModelConfiguration

    if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
      let appSupportURL = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
      let fileManager = FileManager.default

      if !fileManager.fileExists(atPath: appSupportURL.path) {
        do {
          try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
          AppLog.model.info("Created Application Support directory: \(appSupportURL.path, privacy: .public)")
        } catch {
          AppLog.model.notice("Failed to create Application Support directory: \(error.localizedDescription, privacy: .public)")
        }
      }

      modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        groupContainer: .identifier(AppGroup.identifier)
      )
      AppLog.model.info("Using App Group container: \(AppGroup.identifier, privacy: .public)")
    } else {
      AppLog.model.notice("App Group not available, using default container. Widget will not work until App Groups is configured in Xcode.")
      modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
      )
    }

    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
      return .success(container)
    } catch {
      AppLog.model.notice("資料庫遷移失敗，嘗試重新創建: \(error.localizedDescription, privacy: .public)")

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
              AppLog.model.info("Migration: removed \(fileName, privacy: .public)")
              deletedAny = true
            } catch {
              AppLog.model.notice("Migration: could not remove \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
          }
        }
        if !deletedAny {
          for fileName in possibleDBFiles {
            let dbURL = groupURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: dbURL.path) {
              do {
                try fileManager.removeItem(at: dbURL)
                AppLog.model.info("Migration: removed \(fileName, privacy: .public)")
                deletedAny = true
              } catch {
                AppLog.model.notice("Migration: could not remove \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
              }
            }
          }
        }

        if deletedAny {
          AppLog.model.info("Migration: cleaned old DB, retrying ModelContainer")
          do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return .success(container)
          } catch {
            AppLog.model.error("Migration: recreate still failed: \(error.localizedDescription, privacy: .public)")
          }
        }
      }

      let errorMessage = """
      \(error.localizedDescription)
      可能原因：未啟用 App Groups、App Group ID 不一致、或資料庫遷移異常。可嘗試刪除 App 後重裝。
      """
      AppLog.model.error("ModelContainer failed: \(errorMessage, privacy: .public)")
      return .failure(ModelStoreError(message: errorMessage))
    }
  }
}

// MARK: - Root（含 ModelContainer 成功／失敗分支）

private struct AppRootView: View {
  @State private var modelResult: Result<ModelContainer, ModelStoreError>
  @StateObject private var experienceStore = ExperienceStore()
  @StateObject private var taskService = TaskService()
  @StateObject private var dailyQuestService = DailyQuestService()
  @StateObject private var authService = AuthService()
  @StateObject private var pendingInviteStore = PendingInviteStore()
  @StateObject private var pendingBattleOpenStore = PendingBattleOpenStore()
  @StateObject private var battleEnergyStore = BattleEnergyStore()
  @StateObject private var pendingChallengeStore = PendingChallengeStore()
  @Environment(\.scenePhase) private var scenePhase

  init() {
    _modelResult = State(initialValue: KnowledgeBitApp.makeModelContainer())
  }

  var body: some View {
    Group {
      switch modelResult {
      case .success(let container):
        mainContent
          .modelContainer(container)
          .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase, container: container)
          }
      case .failure(let err):
        ModelStoreFailureView(message: err.message) {
          modelResult = KnowledgeBitApp.makeModelContainer()
        }
      }
    }
  }

  @ViewBuilder
  private var mainContent: some View {
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
          .environmentObject(pendingChallengeStore)
          .onAppear {
            experienceStore.authService = authService
            Task {
              try? await Task.sleep(nanoseconds: 500_000_000)
              await authService.syncProfileFromAuthToSupabaseAndAppGroup()
              await experienceStore.loadFromCloud()
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
      handleOpenURL(url)
    }
    .onAppear {
      experienceStore.authService = authService
    }
  }

  private func handleOpenURL(_ url: URL) {
    if let wordSetId = DeepLinkParser.parseWordSetURL(url) {
      pendingBattleOpenStore.setWordSetIdToOpen(wordSetId)
      return
    }
    if let wordSetId = DeepLinkParser.parseBattleURL(url) {
      pendingBattleOpenStore.setBattleWordSetIdToOpen(wordSetId)
      return
    }
    if let challengeId = DeepLinkParser.parseChallengeURL(url) {
      pendingChallengeStore.handleIncomingChallenge(challengeId)
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

  private func handleScenePhase(_ newPhase: ScenePhase, container: ModelContainer) {
    if newPhase == .active {
      UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
      StatisticsManager.shared.flushYesterdayIfNeeded(
        modelContext: container.mainContext,
        dailyQuestService: dailyQuestService
      )
      if authService.isLoggedIn {
        Task {
          try? await Task.sleep(nanoseconds: 500_000_000)
          await authService.syncProfileFromAuthToSupabaseAndAppGroup()
          await experienceStore.loadFromCloud()
          await MainActor.run {
            WidgetReloader.reloadAll()
          }
        }
      }
      refreshNotifications(container: container)
    } else if newPhase == .background {
      refreshStreakReminder(container: container)
    }
  }

  /// 更新 badge 數量，若每日提醒已開啟則重新排程（含最新到期數）
  private func refreshNotifications(container: ModelContainer) {
    let dailyEnabled = UserDefaults.standard.bool(forKey: "notif_daily_enabled")
    let now = Date()
    let dueCount = (try? container.mainContext.fetch(
      FetchDescriptor<Card>(predicate: #Predicate { $0.dueAt <= now })
    ))?.count ?? 0

    NotificationManager.shared.updateBadge(dueCount: dueCount)

    if dailyEnabled {
      let hour = UserDefaults.standard.integer(forKey: "notif_daily_hour")
      let minute = UserDefaults.standard.integer(forKey: "notif_daily_minute")
      let h = UserDefaults.standard.object(forKey: "notif_daily_hour") == nil ? 20 : hour
      NotificationManager.shared.scheduleDailyStudyReminder(hour: h, minute: minute, dueCount: dueCount)
    }
  }

  /// 若連勝提醒已開啟，排程今日 18:00 提醒（今日已學習則跳過）
  private func refreshStreakReminder(container: ModelContainer) {
    guard UserDefaults.standard.bool(forKey: "notif_streak_enabled") else { return }
    let logs = (try? container.mainContext.fetch(
      FetchDescriptor<StudyLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
    )) ?? []
    let studiedToday = logs.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    guard !studiedToday else { return }
    let streak = logs.currentStreak()
    NotificationManager.shared.scheduleStreakRiskReminder(currentStreak: streak)
  }
}
