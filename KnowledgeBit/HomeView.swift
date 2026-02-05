// HomeView.swift
// Home tab view with streak, level, tasks, and daily quiz

import SwiftUI
import SwiftData

struct HomeView: View {
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var taskService: TaskService
  
  @State private var showingAddCardSheet = false
  
  private let srsService = SRSService()
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Header Section
          headerSection
            .padding(.top, 12)
            .padding(.horizontal, 20)
          
          // Streak Card Section
          StreakCardView()
            .padding(.horizontal, 20)
          
          // EXP Card Section
          ExpCardView(experienceStore: experienceStore)
            .padding(.horizontal, 20)
          
          // Due Cards Card Section
          DueCardsCardView()
            .padding(.horizontal, 20)
          
          // Tasks Card Section
          TasksCardView()
            .padding(.horizontal, 20)
          
          // Daily Quiz Button
          dailyQuizButton
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
      .onAppear {
        // 更新到期卡片數量
        srsService.updateDueCountToAppGroup(context: modelContext)
      }
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    HStack(alignment: .center) {
      // App title
      Text("KnowledgeBit")
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(.primary)
      
      Spacer()
      
      // Add button
      Menu {
        Button(action: { showingAddCardSheet = true }) {
          Label("新增單字", systemImage: "plus.circle")
        }
        NavigationLink {
          WordSetListView()
        } label: {
          Label("新增單字集", systemImage: "book.badge.plus")
        }
        NavigationLink {
          CheckInView()
        } label: {
          Label("打卡", systemImage: "calendar")
        }
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(Color.blue)
          .clipShape(Circle())
      }
    }
  }
  
  // MARK: - Daily Quiz Button
  
  private var dailyQuizButton: some View {
    NavigationLink(destination: QuizView()) {
      HStack(spacing: 12) {
        Image(systemName: "play.fill")
          .font(.system(size: 20, weight: .semibold))
        Text("開始每日測驗")
          .font(.system(size: 17, weight: .semibold))
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.blue)
      .cornerRadius(16)
      .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    .buttonStyle(.plain)
  }
}
