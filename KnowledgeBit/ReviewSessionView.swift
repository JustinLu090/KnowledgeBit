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
  @EnvironmentObject var authService: AuthService

  @State private var currentCardIndex = 0
  @State private var isFlipped = false
  @State private var showResult = false
  @State private var reviewedCount = 0

  /// 本次複習開始時間（用於每日任務「學習時長 5 分鐘」）
  @State private var sessionStartTime = Date()

  // TTS 相關
  @AppStorage("tts_auto_speak") private var ttsAutoSpeak = false
  @StateObject private var speech = SpeechService()

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
    .onDisappear {
      speech.stopSpeaking()
    }
  }

  // MARK: - 複習進行中畫面

  private var reviewInProgressView: some View {
    VStack(spacing: 24) {
      // 進度指示 + TTS 開關
      HStack {
        Text("\(currentCardIndex + 1) / \(dueCards.count)")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
        Text("剩餘 \(dueCards.count - currentCardIndex - 1) 張")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        // TTS 音量開關
        Button {
          ttsAutoSpeak.toggle()
        } label: {
          Image(systemName: ttsAutoSpeak ? "speaker.wave.2.fill" : "speaker.slash")
            .font(.system(size: 18))
            .foregroundStyle(ttsAutoSpeak ? Color.accentColor : Color.secondary)
            .frame(width: 40, height: 40)
        }
      }
      .padding(.horizontal)
      .padding(.top)

      Spacer()

      // 卡片顯示
      if currentCardIndex < dueCards.count {
        let card = dueCards[currentCardIndex]

        VStack(spacing: 20) {
          // 卡片正面（標題）
          GeometryReader { geo in
            Text(card.title)
              .font(.system(size: FlashcardTextSizing.fontSize(for: card.title, base: 30), weight: .bold))
              .foregroundStyle(.primary)
              .multilineTextAlignment(.center)
              .minimumScaleFactor(0.32)
              .lineLimit(nil)
              .frame(width: max(0, geo.size.width - 24), height: geo.size.height, alignment: .center)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
            GeometryReader { geo in
              Text(card.content)
                .font(.system(size: FlashcardTextSizing.fontSize(for: card.content, base: 17), weight: .regular))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.35)
                .lineLimit(nil)
                .frame(width: max(0, geo.size.width - 24), height: geo.size.height, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            .transition(.opacity.combined(with: .scale))
          }
        }
        .onChange(of: isFlipped) { _, newValue in
          // 翻到背面時依序朗讀：正面 → 停頓 0.5 秒 → 背面
          if newValue && ttsAutoSpeak {
            speech.speakCard(
              front: card.title,
              back: card.content,
              language: card.wordSet?.language
            )
          }
        }
      }

      Spacer()

      // 操作按鈕（只有翻面後才顯示）
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

  // MARK: - 複習卡片

  private func reviewCard(result: ReviewResult) {
    guard currentCardIndex < dueCards.count else { return }

    let card = dueCards[currentCardIndex]

    srsService.applyReview(card: card, result: result)
    taskService.incrementReviewCount()
    reviewedCount += 1

    try? modelContext.save()
    if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
      Task { await sync.syncCard(card) }
    }

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

// MARK: - Preview
#Preview {
  ReviewSessionView()
    .environmentObject(ExperienceStore())
    .environmentObject(TaskService())
    .environmentObject(DailyQuestService())
    .environmentObject(AuthService())
    .modelContainer(for: Card.self, inMemory: true)
}
