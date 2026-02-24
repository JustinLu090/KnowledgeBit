// ReviewSessionView.swift
// SRS 複習介面

import SwiftUI
import SwiftData

struct ReviewSessionView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var taskService: TaskService
  @EnvironmentObject var questService: DailyQuestService

  @State private var currentCardIndex = 0
  @State private var isFlipped = false
  @State private var showResult = false
  @State private var reviewedCount = 0

  /// 本次複習開始時間（用於每日任務「學習時長 5 分鐘」）
  @State private var sessionStartTime = Date()

  private let srsService = SRSService()
  private var dueCards: [Card] {
    srsService.getDueCards(now: Date(), context: modelContext)
  }

  var body: some View {
    Group {
      if showResult {
        reviewCompleteView
      } else if dueCards.isEmpty {
        ContentUnavailableView(
          "沒有到期卡片",
          systemImage: "checkmark.circle.fill",
          description: Text("所有卡片都已複習完成！")
        )
      } else {
        reviewInProgressView
      }
    }
    .onAppear {
      sessionStartTime = Date()
      srsService.updateDueCountToAppGroup(context: modelContext)
    }
  }

  private var reviewInProgressView: some View {
    VStack(spacing: 24) {
      HStack {
        Text("\(currentCardIndex + 1) / \(dueCards.count)")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
        Text("剩餘 \(max(0, dueCards.count - currentCardIndex - 1)) 張")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal)
      .padding(.top)

      Spacer()

      if currentCardIndex < dueCards.count {
        let card = dueCards[currentCardIndex]

        VStack(spacing: 20) {
          // Front
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

          // Back (✅ Markdown)
          if isFlipped {
            VStack(alignment: .leading, spacing: 12) {
              ScrollView {
                MarkdownText(markdown: card.content, font: .body)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding()
              }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            .transition(.opacity.combined(with: .scale))
          }
        }
      }

      Spacer()

      if isFlipped {
        HStack(spacing: 20) {
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

      Button(action: { dismiss() }) {
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

  private func reviewCard(result: ReviewResult) {
    guard currentCardIndex < dueCards.count else { return }

    let card = dueCards[currentCardIndex]
    srsService.applyReview(card: card, result: result)

    taskService.incrementReviewCount()
    reviewedCount += 1

    try? modelContext.save()

    withAnimation {
      if currentCardIndex < dueCards.count - 1 {
        currentCardIndex += 1
        isFlipped = false
      } else {
        let sessionMinutes = max(0, Int(Date().timeIntervalSince(sessionStartTime) / 60))
        if sessionMinutes > 0 {
          questService.recordStudyMinutes(sessionMinutes, experienceStore: experienceStore)
        }
        showResult = true
        _ = taskService.completeReviewTask(reviewCount: reviewedCount, experienceStore: experienceStore)
        srsService.updateDueCountToAppGroup(context: modelContext)
      }
    }
  }
}
