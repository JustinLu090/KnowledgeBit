// MainTabView.swift
// Main tab bar navigation structure with enhanced styling

import SwiftUI
import SwiftData

/// Thin Identifiable wrapper so UUID can drive .sheet(item:)
private struct ChallengeSheetItem: Identifiable {
  let id: UUID
}

struct MainTabView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var dailyQuestService: DailyQuestService
  @EnvironmentObject var pendingInviteStore: PendingInviteStore
  @EnvironmentObject var pendingBattleOpenStore: PendingBattleOpenStore
  @EnvironmentObject var pendingChallengeStore: PendingChallengeStore
  @StateObject private var communityViewModel = CommunityViewModel()
  @ObservedObject private var achievementService = AchievementService.shared
  @Query(sort: \StudyLog.date, order: .reverse) private var studyLogs: [StudyLog]
  @State private var selectedTab = 0
  @State private var pendingChallengeItem: ChallengeSheetItem?
  
  init() {
    // Configure tab bar appearance globally
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    
    // Semi-transparent background with blur effect
    appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
    
    // Normal state
    appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
      .foregroundColor: UIColor.secondaryLabel
    ]
    
    // Selected state
    appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
      .foregroundColor: UIColor.systemBlue
    ]
    
    UITabBar.appearance().standardAppearance = appearance
    if #available(iOS 15.0, *) {
      UITabBar.appearance().scrollEdgeAppearance = appearance
    }
  }
  
  var body: some View {
    TabView(selection: $selectedTab) {
      HomeView()
        .tabItem {
          Label("首頁", systemImage: "house.fill")
        }
        .tag(0)
      
      LibraryView()
        .tabItem {
          Label("單字集", systemImage: "book.fill")
        }
        .tag(1)
      
      communityTab

      BattleView()
        .tabItem {
          Label("對戰", systemImage: "trophy.fill")
        }
        .tag(3)

      ProfileView()
        .tabItem {
          Label("個人", systemImage: "person.fill")
        }
        .tag(4)
    }
    .tint(.blue)
    .sheet(item: $pendingChallengeItem) { item in
      ChallengeDetailView(challengeId: item.id)
        .environmentObject(authService)
        .environmentObject(experienceStore)
        .environmentObject(pendingChallengeStore)
    }
    .onChange(of: pendingChallengeStore.challengeId) { _, newId in
      if let id = newId {
        pendingChallengeItem = ChallengeSheetItem(id: id)
        pendingChallengeStore.clear()
      }
    }
    .overlay {
      if let unlocked = achievementService.newlyUnlocked {
        AchievementUnlockOverlay(achievement: unlocked) {
          achievementService.dismissNewlyUnlocked()
        }
        .zIndex(999)
        .transition(.opacity)
      }
    }
    .onChange(of: pendingBattleOpenStore.wordSetIdToOpen) { _, new in
      guard new != nil else { return }
      switch pendingBattleOpenStore.openKind {
      case .battle:
        selectedTab = 3
      case .wordSet:
        selectedTab = 1
      case .none:
        break
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      // App 回到前景時將昨日 EXP/學習時長寫入 DailyStats（若已跨日）
      StatisticsManager.shared.flushYesterdayIfNeeded(modelContext: modelContext, dailyQuestService: dailyQuestService)
      // 更新社群頁好友請求數量（badge）
      Task { await communityViewModel.refresh(authService: authService) }
      // 評估成就
      let streak = studyLogs.currentStreak()
      AchievementService.shared.evaluate(level: experienceStore.level, streak: streak)
    }
    .task {
      // 首次進入時評估成就
      let streak = studyLogs.currentStreak()
      AchievementService.shared.evaluate(level: experienceStore.level, streak: streak)
    }
  }

  @ViewBuilder
  private var communityTab: some View {
    let base = CommunityView(viewModel: communityViewModel, pendingInviteStore: pendingInviteStore)
      .tabItem {
        Label("社群", systemImage: "person.3.fill")
      }
      .tag(2)
    if communityViewModel.pendingCount > 0 {
      base.badge(communityViewModel.pendingCount)
    } else {
      base
    }
  }
}
