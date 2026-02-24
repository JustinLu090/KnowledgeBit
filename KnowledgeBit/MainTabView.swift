// MainTabView.swift
// Main tab bar navigation structure with enhanced styling

import SwiftUI
import SwiftData

struct MainTabView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var dailyQuestService: DailyQuestService
  @EnvironmentObject var pendingInviteStore: PendingInviteStore
  @StateObject private var communityViewModel = CommunityViewModel()
  @State private var selectedTab = 0
  
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
      
      AchievementsView()
        .tabItem {
          Label("成就", systemImage: "chart.bar.fill")
        }
        .tag(3)
      
      ProfileView()
        .tabItem {
          Label("個人", systemImage: "person.fill")
        }
        .tag(4)
    }
    .tint(.blue)
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      // App 回到前景時將昨日 EXP/學習時長寫入 DailyStats（若已跨日）
      StatisticsManager.shared.flushYesterdayIfNeeded(modelContext: modelContext, dailyQuestService: dailyQuestService)
      // 更新社群頁好友請求數量（badge）
      Task { await communityViewModel.refresh(authService: authService) }
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
