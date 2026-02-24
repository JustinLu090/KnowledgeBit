// DailyQuestsView.swift
// Daily quests card view with Duolingo-style design

import SwiftUI

struct DailyQuestsView: View {
  @EnvironmentObject var questService: DailyQuestService
  @EnvironmentObject var experienceStore: ExperienceStore
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header with title and progress
      HStack {
        Text("每日任務")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.primary)
        
        Spacer()
        
        // Progress indicator
        Text("\(questService.completedCount)/\(questService.totalCount)")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.blue)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(12)
      }
      
      // Quest cards
      VStack(spacing: 12) {
        ForEach(questService.quests) { quest in
          QuestCardView(quest: quest)
        }
      }
    }
    .cardStyle(withShadow: true)
    .onAppear {
      // 每次顯示首頁時從 UserDefaults 同步，確保進度與持久化一致
      questService.refreshFromStorage()
    }
  }
}

// MARK: - Quest Card View

struct QuestCardView: View {
  let quest: DailyQuest
  
  var body: some View {
    HStack(spacing: 12) {
      // Left: Icon
      Image(systemName: quest.iconName)
        .font(.system(size: 20))
        .foregroundStyle(quest.isCompleted ? .green : .blue)
        .frame(width: 32, height: 32)
        .background(
          (quest.isCompleted ? Color.green : Color.blue).opacity(0.1)
        )
        .clipShape(Circle())
      
      // Middle: Title and progress bar
      VStack(alignment: .leading, spacing: 6) {
        Text(quest.displayTitle)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(quest.isCompleted ? .secondary : .primary)
        
        // Progress bar (matching ExpCardView style)
        ProgressView(value: quest.progressPercentage)
          .progressViewStyle(.linear)
          .tint(quest.isCompleted ? .green : .blue)
          .scaleEffect(x: 1, y: 1.5, anchor: .center) // Match ExpCardView scale
        
        // Progress text
        Text("\(quest.currentProgress) / \(quest.targetValue)")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      // Right: Reward or checkmark
      if quest.isCompleted {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 24))
          .foregroundStyle(.green)
      } else {
        VStack(spacing: 2) {
          Text("+\(quest.rewardExp)")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.blue)
          Text("EXP")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(14)
    .background(
      quest.isCompleted 
        ? Color.green.opacity(0.05)
        : Color.blue.opacity(0.03)
    )
    .cornerRadius(15)
  }
}

// MARK: - Preview

#Preview {
  DailyQuestsView()
    .environmentObject(ExperienceStore())
    .environmentObject(DailyQuestService())
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
