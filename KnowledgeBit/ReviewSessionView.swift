// ReviewSessionView.swift
// SRS 複習介面

import SwiftUI
import SwiftData

struct ReviewSessionView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var taskService: TaskService
  
  @State private var currentCardIndex = 0
  @State private var isFlipped = false
  @State private var showResult = false
  @State private var reviewedCount = 0
  
  private let srsService = SRSService()
  private var dueCards: [Card] {
    srsService.getDueCards(now: Date(), context: modelContext)
  }
  
  var body: some View {
    Group {
      if showResult {
        // 複習完成畫面
        reviewCompleteView
      } else if dueCards.isEmpty {
        // 沒有到期卡片
        ContentUnavailableView(
          "沒有到期卡片",
          systemImage: "checkmark.circle.fill",
          description: Text("所有卡片都已複習完成！")
        )
      } else {
        // 複習進行中
        reviewInProgressView
      }
    }
    .onAppear {
      // 更新到期卡片數量
      srsService.updateDueCountToAppGroup(context: modelContext)
    }
  }
  
  // MARK: - 複習進行中畫面
  private var reviewInProgressView: some View {
    VStack(spacing: 24) {
      // 進度指示
      HStack {
        Text("\(currentCardIndex + 1) / \(dueCards.count)")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
        Text("剩餘 \(dueCards.count - currentCardIndex - 1) 張")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal)
      .padding(.top)
      
      Spacer()
      
      // 卡片顯示
      if currentCardIndex < dueCards.count {
        let card = dueCards[currentCardIndex]
        
        VStack(spacing: 20) {
          // 卡片正面（標題）
          VStack(spacing: 16) {
            Text(card.title)
              .font(.system(size: 32, weight: .bold))
              .foregroundStyle(.primary)
              .multilineTextAlignment(.center)
              .padding()
          }
          .frame(maxWidth: .infinity)
          .frame(height: 300)
          .background(Color(.secondarySystemGroupedBackground))
          .cornerRadius(20)
          .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
          .padding(.horizontal)
          .onTapGesture {
            withAnimation(.spring()) {
              isFlipped.toggle()
            }
          }
          
          // 卡片背面（內容）- 只有翻面後才顯示
          if isFlipped {
            VStack(spacing: 16) {
              Text(card.content)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .padding()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            .transition(.opacity.combined(with: .scale))
          }
        }
      }
      
      Spacer()
      
      // 操作按鈕（只有翻面後才顯示）
      if isFlipped {
        HStack(spacing: 20) {
          // 不記得按鈕
          Button(action: { reviewCard(result: .forgotten) }) {
            VStack(spacing: 8) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)
              Text("不記得")
                .font(.headline)
                .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.red.opacity(0.1))
            .cornerRadius(16)
          }
          
          // 記得按鈕
          Button(action: { reviewCard(result: .remembered) }) {
            VStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
              Text("記得")
                .font(.headline)
                .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.green.opacity(0.1))
            .cornerRadius(16)
          }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
      } else {
        Text("點擊卡片查看答案")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.bottom, 40)
      }
    }
  }
  
  // MARK: - 複習完成畫面
  private var reviewCompleteView: some View {
    VStack(spacing: 24) {
      Spacer()
      
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 80))
        .foregroundStyle(.green)
      
      Text("複習完成！")
        .font(.system(size: 32, weight: .bold))
      
      Text("今天已複習 \(reviewedCount) 張卡片")
        .font(.title3)
        .foregroundStyle(.secondary)
      
      Spacer()
      
      Button(action: {
        dismiss()
      }) {
        Text("完成")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(Color.accentColor)
          .cornerRadius(16)
      }
      .padding(.horizontal, 40)
      .padding(.bottom, 40)
    }
  }
  
  // MARK: - 複習卡片
  private func reviewCard(result: ReviewResult) {
    guard currentCardIndex < dueCards.count else { return }
    
    let card = dueCards[currentCardIndex]
    
    // 應用複習結果
    srsService.applyReview(card: card, result: result)
    
    // 增加今日複習數量
    taskService.incrementReviewCount()
    reviewedCount += 1
    
    // 儲存變更
    try? modelContext.save()
    
    // 移到下一張
    withAnimation {
      if currentCardIndex < dueCards.count - 1 {
        currentCardIndex += 1
        isFlipped = false
      } else {
        // 所有卡片都複習完畢
        showResult = true
        
        // 檢查並完成複習任務
        _ = taskService.completeReviewTask(reviewCount: reviewedCount, experienceStore: experienceStore)
        
        // 更新到期卡片數量
        srsService.updateDueCountToAppGroup(context: modelContext)
      }
    }
  }
}

// MARK: - Preview
#Preview {
  ReviewSessionView()
    .environmentObject(ExperienceStore())
    .environmentObject(TaskService())
    .modelContainer(for: Card.self, inMemory: true)
}
