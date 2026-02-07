// TasksCardView.swift
// 顯示今日任務進度的元件

import SwiftUI

struct TasksCardView: View {
  @EnvironmentObject var taskService: TaskService
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 標題
      HStack {
        Image(systemName: "checkmark.circle.fill")
          .font(.title2)
          .foregroundStyle(.green)
        Text("今日任務")
          .font(.headline)
          .foregroundStyle(.primary)
        Spacer()
      }
      
      // 任務列表
      VStack(spacing: 12) {
        // 任務 A：完成複習 session（至少 10 張）
        TaskRowView(
          title: "完成複習（10 張）",
          isDone: taskService.reviewTaskDone,
          reward: "+30 EXP"
        )
        
        // 任務 B：完成每日測驗
        TaskRowView(
          title: "完成每日測驗",
          isDone: taskService.quizTaskDone,
          reward: "+20 EXP"
        )
      }
    }
    .cardStyle()
  }
}

// MARK: - TaskRowView
struct TaskRowView: View {
  let title: String
  let isDone: Bool
  let reward: String
  
  var body: some View {
    HStack(spacing: 12) {
      // 完成狀態圖示
      Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
        .font(.title3)
        .foregroundStyle(isDone ? .green : .secondary)
      
      // 任務標題
      Text(title)
        .font(.body)
        .foregroundStyle(isDone ? .secondary : .primary)
        .strikethrough(isDone)
      
      Spacer()
      
      // 獎勵
      Text(reward)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(isDone ? .green : .blue)
    }
  }
}

// MARK: - Preview
#Preview {
  TasksCardView()
    .environmentObject(TaskService())
    .padding()
    .background(Color(.systemGroupedBackground))
}
