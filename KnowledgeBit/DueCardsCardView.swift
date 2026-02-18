// DueCardsCardView.swift
// 顯示今日到期複習卡片數的元件

import SwiftUI
import SwiftData

struct DueCardsCardView: View {
  @Environment(\.modelContext) private var modelContext
  
  private let srsService = SRSService()
  
  // 計算今日到期卡片數
  private var todayDueCount: Int {
    srsService.getTodayDueCount(context: modelContext)
  }
  
  var body: some View {
    NavigationLink(destination: ReviewSessionView()) {
      HStack(spacing: 16) {
        Image(systemName: "clock.fill")
          .font(.largeTitle)
          .foregroundStyle(
            LinearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        
        VStack(alignment: .leading, spacing: 4) {
          Text("今日到期複習")
            .font(.headline)
            .foregroundStyle(.primary)
          
          if todayDueCount > 0 {
            Text("\(todayDueCount) 張卡片")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundStyle(.primary)
          } else {
            Text("已完成")
              .font(.title3)
              .foregroundStyle(.secondary)
          }
        }
        
        Spacer()
        
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .cardStyle()
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview
#Preview {
  DueCardsCardView()
    .modelContainer(for: Card.self, inMemory: true)
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
