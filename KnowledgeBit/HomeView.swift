// HomeView.swift
// Home tab view with streak, level, tasks, and daily quiz

import SwiftUI
import SwiftData

struct HomeView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var taskService: TaskService
  
  @State private var showingAddCardSheet = false
  @State private var showingAppGuide = false
  
  private let srsService = SRSService()
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HomeHeaderSection(showingAddCardSheet: $showingAddCardSheet, showingAppGuide: $showingAppGuide)
            .padding(.top, 12)
            .padding(.horizontal, 20)
          
          StreakCardView()
            .padding(.horizontal, 20)
          
          ExpCardView(experienceStore: experienceStore)
            .padding(.horizontal, 20)
          
          DailyQuestsView()
            .padding(.horizontal, 20)
          
          // Bottom padding
          Spacer()
            .frame(height: 32)
        }
      }
      .background(Color(.systemGroupedBackground))
      .sheet(isPresented: $showingAddCardSheet) {
        AddCardView()
      }
      .fullScreenCover(isPresented: $showingAppGuide) {
        AppGuideView()
      }
      .onAppear {
        // 更新到期卡片數量
        srsService.updateDueCountToAppGroup(context: modelContext)
      }
    }
  }
}
