// ExpCardView.swift
// 顯示使用者等級與 EXP 進度條的卡片元件

import SwiftUI

struct ExpCardView: View {
  @ObservedObject var experienceStore: ExperienceStore
  
  var body: some View {
    VStack(spacing: 16) {
      // 標題與等級
      HStack {
        Image(systemName: "star.fill")
          .font(.largeTitle)
          .foregroundStyle(
            LinearGradient(
              colors: [.yellow, .orange],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        
        VStack(alignment: .leading, spacing: 4) {
          Text("等級")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Lv.\(experienceStore.level)")
            .font(.title2)
            .bold()
        }
        
        Spacer()
      }
      
      // EXP 進度條
      VStack(alignment: .leading, spacing: 8) {
        // EXP 數值顯示
        HStack {
          Text("EXP")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          Text("\(experienceStore.exp) / \(experienceStore.expToNext)")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
          Text("(\(Int(experienceStore.expPercentage * 100))%)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        
        // 進度條
        ProgressView(value: experienceStore.expPercentage)
          .progressViewStyle(.linear)
          .tint(.blue)
          .scaleEffect(x: 1, y: 1.5, anchor: .center) // 讓進度條稍微高一點
      }
    }
    .padding(20)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
  }
}

// MARK: - Preview
#Preview {
  let store = ExperienceStore()
  return ExpCardView(experienceStore: store)
    .padding()
    .background(Color(.systemGroupedBackground))
}
