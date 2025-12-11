import SwiftUI
import SwiftData

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

  // 2. 測驗狀態
  @State private var currentCardIndex = 0
  @State private var isFlipped = false
  @State private var showResult = false
  @State private var score = 0

  // 為了不破壞原始順序，我們在出現時把卡片打亂
  @State private var shuffledCards: [Card] = []
  
  // Computed property to get cards to use
  private var cardsToUse: [Card] {
    cards ?? allCards
  }
  
  // Calculate streak using the same logic as StatsView
  private var currentStreak: Int {
    guard !logs.isEmpty else { return 0 }
    
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // Group study dates (multiple logs on same day count as one day)
    var studyDates = Set<Date>()
    for log in logs {
      let logDate = calendar.startOfDay(for: log.date)
      studyDates.insert(logDate)
    }
    
    // Calculate consecutive days from today backwards
    var streak = 0
    var currentDate = today
    
    while studyDates.contains(currentDate) {
      streak += 1
      guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
        break
      }
      currentDate = previousDate
    }
    
    return streak
  }

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
            dismiss()
          },
          onRetry: {
            retryQuiz()
          }
        )
      } else {
        // 測驗進行中的畫面
        VStack {
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
    .onAppear {
      // 進入畫面時，將資料庫的卡片洗牌
      shuffledCards = cardsToUse.shuffled()
    }
  }

  func saveStudyLog() {
    let today = Date()
    // 建立一筆新紀錄
    let log = StudyLog(date: today, cardsReviewed: score)
    // 插入資料庫
    modelContext.insert(log)
    try? modelContext.save()

    print("已儲存打卡紀錄：\(today)")
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
