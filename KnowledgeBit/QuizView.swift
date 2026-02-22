import SwiftUI
import SwiftData
import Combine

struct QuizView: View {
  // Optional: specific cards to quiz (e.g., from a WordSet)
  // If nil, uses @Query to fetch all cards
  var cards: [Card]? = nil
  
  // Fallback query for all cards if cards parameter is nil
  @Query(sort: \Card.createdAt, order: .reverse) private var allCards: [Card]
  
  // Query for StudyLogs to calculate streak
  @Query(sort: \StudyLog.date, order: .reverse) private var logs: [StudyLog]
  
  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var taskService: TaskService
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var questService: DailyQuestService

  // 2. 測驗狀態
  @State private var currentCardIndex = 0
  @State private var isFlipped = false
  @State private var showResult = false
  @State private var score = 0
  @State private var showExitConfirmation = false

  // 為了不破壞原始順序，我們在出現時把卡片打亂
  @State private var shuffledCards: [Card] = []
  
  /// 本次測驗開始時間（用於每日任務「學習時長 5 分鐘」）
  @State private var sessionStartTime = Date()
  
  private let srsService = SRSService()
  
  // Computed property to get cards to use
  // 優先使用到期卡片，如果沒有到期卡片則使用所有卡片
  private var cardsToUse: [Card] {
    if let specificCards = cards {
      return specificCards
    }
    
    // 優先取得到期卡片
    let dueCards = srsService.getDueCards(now: Date(), context: modelContext)
    if !dueCards.isEmpty {
      return dueCards
    }
    
    // 如果沒有到期卡片，使用所有卡片
    return allCards
  }
  
  private var currentStreak: Int { logs.currentStreak() }

  var body: some View {
    Group {
      if showResult {
        // 測驗結束畫面 - 使用新的 QuizResultView (全螢幕)
        QuizResultView(
          rememberedCards: score,
          totalCards: shuffledCards.count,
          streakDays: currentStreak,
          onFinish: {
            saveStudyLog()
            // 學習時長：本次測驗耗時（分鐘），更新每日任務「學習時長 5 分鐘」
            let sessionMinutes = max(0, Int(Date().timeIntervalSince(sessionStartTime) / 60))
            if sessionMinutes > 0 {
              questService.recordStudyMinutes(sessionMinutes, experienceStore: experienceStore)
            }
            let isWordSetQuiz = (cards != nil && !(cards ?? []).isEmpty)
            if isWordSetQuiz {
              // 單字集複習：更新「完成一本/兩本單字集複習」「答對率 90%」「全對」
              questService.recordWordSetCompleted(experienceStore: experienceStore)
              let total = shuffledCards.count
              let accuracy = total > 0 ? Int(Double(score) / Double(total) * 100) : 0
              questService.recordWordSetQuizResult(accuracyPercent: accuracy, isPerfect: (total > 0 && score == total), experienceStore: experienceStore)
            } else {
              // 每日測驗：完成一次 → 20 EXP，並計入「獲得 30 經驗值」進度
              if taskService.completeQuizTask(experienceStore: experienceStore) {
                questService.recordExpGainedToday(20, experienceStore: experienceStore)
              }
            }
            dismiss()
          },
          onRetry: {
            retryQuiz()
          }
        )
      } else {
        // 測驗進行中的畫面
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
        // 顯示卡片 (點擊翻面)
        FlipCardView(
          card: shuffledCards[currentCardIndex],
          isFlipped: $isFlipped
        )
        .frame(height: 400)
        .padding()
        .onTapGesture {
          withAnimation(.spring()) {
            isFlipped.toggle()
          }
        }

        Spacer()

        // 下方按鈕 (只有翻面後才顯示)
        if isFlipped {
          HStack(spacing: 40) {
            Button(action: { nextCard(isCorrect: false) }) {
              VStack {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 50))
                  .foregroundStyle(.red)
                Text("忘了")
                  .font(.caption)
              }
            }

            Button(action: { nextCard(isCorrect: true) }) {
              VStack {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 50))
                  .foregroundStyle(.green)
                Text("記住了")
                  .font(.caption)
              }
            }
          }
          .padding(.bottom, 50)
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
      // 進入畫面時，將資料庫的卡片洗牌，並記錄開始時間（供每日任務學習時長）
      shuffledCards = cardsToUse.shuffled()
      sessionStartTime = Date()
    }
  }

  func saveStudyLog() {
    // 使用當地時區的「當日開始」作為打卡日期，避免 UTC 與當地時間差
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
