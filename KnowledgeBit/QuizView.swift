import SwiftUI
import SwiftData
import Combine
import Foundation

struct QuizView: View {
  var cards: [Card]? = nil

  @Query(sort: \Card.createdAt, order: .reverse) private var allCards: [Card]
  @Query(sort: \StudyLog.date, order: .reverse) private var logs: [StudyLog]

  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var taskService: TaskService
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var questService: DailyQuestService

  @State private var currentCardIndex = 0
  @State private var isFlipped = false
  @State private var showResult = false
  @State private var score = 0
  @State private var showExitConfirmation = false

  // 為了不破壞原始順序，我們在出現時把卡片打亂
  @State private var shuffledCards: [Card] = []
  @State private var sessionStartTime = Date()

  // ✅ 詳解展開：永遠可用（翻到背面就顯示按鈕）
  @State private var showDetail = false

  private let srsService = SRSService()

  private var cardsToUse: [Card] {
    if let specificCards = cards { return specificCards }

    let dueCards = srsService.getDueCards(now: Date(), context: modelContext)
    if !dueCards.isEmpty { return dueCards }

    return allCards
  }

  private var currentStreak: Int { logs.currentStreak() }

  var body: some View {
    Group {
      if showResult {
        QuizResultView(
          rememberedCards: score,
          totalCards: shuffledCards.count,
          streakDays: currentStreak,
          onFinish: {
            saveStudyLog()
            let sessionMinutes = max(0, Int(Date().timeIntervalSince(sessionStartTime) / 60))
            if sessionMinutes > 0 {
              questService.recordStudyMinutes(sessionMinutes, experienceStore: experienceStore)
            }
            let isWordSetQuiz = (cards != nil && !(cards ?? []).isEmpty)
            if isWordSetQuiz {
              questService.recordWordSetCompleted(experienceStore: experienceStore)
              let total = shuffledCards.count
              let accuracy = total > 0 ? Int(Double(score) / Double(total) * 100) : 0
              questService.recordWordSetQuizResult(accuracyPercent: accuracy, isPerfect: (total > 0 && score == total), quizType: .general, experienceStore: experienceStore)
            } else {
              if taskService.completeQuizTask(experienceStore: experienceStore) {
                questService.recordExpGainedToday(20, experienceStore: experienceStore)
              }
            }
            dismiss()
          },
          onRetry: { retryQuiz() }
        )
      } else {
        VStack {
          // 左上角退出鈕
          HStack {
            Button {
              if currentCardIndex > 0 || isFlipped {
                showExitConfirmation = true
              } else {
                dismiss()
              }
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
            }
            Spacer()
          }
          .padding(.horizontal)
          .padding(.top, 8)

          // 上方進度條
          if !shuffledCards.isEmpty {
            Text("Question \(currentCardIndex + 1) / \(shuffledCards.count)")
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.top)
          }

          Spacer()

          if shuffledCards.isEmpty {
            // 如果沒有卡片
            ContentUnavailableView("沒有卡片", systemImage: "tray.fill", description: Text("請先新增知識卡片才能開始測驗"))
          } else {
            let currentCard = shuffledCards[currentCardIndex]

            FlipCardView(card: currentCard, isFlipped: $isFlipped)
              .frame(height: 400)
              .padding()
              .onTapGesture {
                withAnimation(.spring()) {
                  isFlipped.toggle()
                }
              }

            Spacer()

            if isFlipped {
              // ✅ 背面：直接提供「查看詳解」＋「忘了/記住了」
              VStack(spacing: 14) {

                // 1) 查看詳解（永遠可用）
                HStack(spacing: 12) {
                  Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                      showDetail.toggle()
                    }
                  } label: {
                    HStack(spacing: 10) {
                      Image(systemName: "text.justify.left")
                        .font(.headline)
                      Text(showDetail ? "收合詳解" : "查看詳解")
                        .font(.headline.weight(.semibold))
                      Spacer()
                      Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .rotationEffect(.degrees(showDetail ? 90 : 0))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(.primary)
                    .background(
                      RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                    )
                  }
                  .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                // 2) 詳解內容（展開才顯示 / Markdown）
                if showDetail {
                  detailBlock(markdown: currentCard.content)
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // 3) 忘了 / 記住了（按了直接提交 + 下一題）
                HStack(spacing: 40) {
                  Button {
                    commitAndNext(isRemembered: false)
                  } label: {
                    VStack(spacing: 8) {
                      Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)
                      Text("忘了")
                        .font(.caption.weight(.semibold))
                    }
                  }
                  .buttonStyle(.plain)

                  Button {
                    commitAndNext(isRemembered: true)
                  } label: {
                    VStack(spacing: 8) {
                      Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                      Text("記住了")
                        .font(.caption.weight(.semibold))
                    }
                  }
                  .buttonStyle(.plain)
                }
                .padding(.top, 6)
                .padding(.bottom, 6)

                Text("可先查看詳解，再選擇是否記住")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
                  .padding(.bottom, 18)
              }

            } else {
              Text("點擊卡片查看答案")
                .foregroundStyle(.secondary)
                .padding(.bottom, 50)
            }
          }
        }
      }
    }
    .alert("確定要退出嗎？", isPresented: $showExitConfirmation) {
      Button("取消", role: .cancel) {}
      Button("確定", role: .destructive) { dismiss() }
    } message: {
      Text("目前進度將不會儲存。")
    }
    .onAppear {
      shuffledCards = cardsToUse.shuffled()
      sessionStartTime = Date()
    }
  }

  // MARK: - Detail Markdown Block

  @ViewBuilder
  private func detailBlock(markdown: String) -> some View {
    let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)

    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("詳細說明")
          .font(.headline.weight(.semibold))
        Spacer()
      }

      if trimmed.isEmpty {
        Text("（尚未填寫詳細說明）")
          .foregroundStyle(.secondary)
      } else {
        MarkdownTextView(markdown: trimmed)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.primary.opacity(0.04))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    )
  }

  // MARK: - Save / Next

  private func saveStudyLog() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let total = shuffledCards.count
    let log = StudyLog(date: today, cardsReviewed: score, totalCards: total)
    modelContext.insert(log)
    try? modelContext.save()
  }

  // 切換下一張邏輯
  func nextCard(isCorrect: Bool) {
    if isCorrect {
      score += 1
      // 這裡未來可以加入邏輯：將卡片標記為「已精通」
    }

    withAnimation {
      if currentCardIndex < shuffledCards.count - 1 {
        isFlipped = false
        currentCardIndex += 1
      } else {
        showResult = true
      }
    }
  }
  
  // Retry quiz - reset all state and reshuffle cards
  func retryQuiz() {
    withAnimation {
      currentCardIndex = 0
      isFlipped = false
      showResult = false
      score = 0
      shuffledCards = cardsToUse.shuffled()
    }
  }
}
