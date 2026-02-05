// MainTabView.swift
// Main tab bar navigation structure with enhanced styling

import SwiftUI

struct MainTabView: View {
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
      
      BattleView()
        .tabItem {
          Label("對戰", systemImage: "trophy.fill")
        }
        .tag(2)
      
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
  }
}
