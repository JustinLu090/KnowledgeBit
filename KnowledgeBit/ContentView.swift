// ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext

  // 控制新增視窗的開關
  @State private var showingAddCardSheet = false
  @State private var showingSettingsSheet = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Header Section
          headerSection
            .padding(.top, 12)
            .padding(.horizontal, 20)
          
          // Streak Card Section
          StatsView()
            .padding(.horizontal, 20)
          
          // Daily Quiz Button
          dailyQuizButton
            .padding(.horizontal, 20)
          
          // Word Set Section
          wordSetCard
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
      .sheet(isPresented: $showingSettingsSheet) {
        SettingsView()
      }
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    HStack(alignment: .center) {
      // Settings button
      Button(action: { showingSettingsSheet = true }) {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 18))
          .foregroundStyle(.secondary)
          .frame(width: 36, height: 36)
          .background(Color(.systemGray6))
          .clipShape(Circle())
      }
      
      Spacer()
      
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
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(Color.accentColor)
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
      .background(Color.accentColor)
      .cornerRadius(16)
    }
    .buttonStyle(.plain)
  }
  
  // MARK: - Word Set Card
  
  private var wordSetCard: some View {
    NavigationLink {
      WordSetListView()
    } label: {
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("單字集")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.primary)
          
          Text("管理你的單字集")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(20)
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(16)
    }
    .buttonStyle(.plain)
  }
}
