import SwiftUI
import SwiftData

struct QuizView: View {
  // 1. 抓取所有卡片
  @Query private var cards: [Card]
  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext

  // 2. 測驗狀態
  @State private var currentCardIndex = 0
  @State private var isFlipped = false
  @State private var showResult = false
  @State private var score = 0

  // 為了不破壞原始順序，我們在出現時把卡片打亂
  @State private var shuffledCards: [Card] = []

  var body: some View {
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
      } else if showResult {
        // 測驗結束畫面
        VStack(spacing: 20) {
          Image(systemName: "trophy.fill")
            .font(.system(size: 80))
            .foregroundStyle(.yellow)
          Text("測驗完成！")
            .font(.title)
            .bold()
          Text("你記住了 \(score) 張卡片")
            .font(.headline)

          Button("完成") {
            saveStudyLog() // 呼叫存檔
            dismiss()
          }
          .buttonStyle(.borderedProminent)
        }
      } else {
        // 顯示卡片 (點擊翻面)
        ZStack {
          RoundedRectangle(cornerRadius: 20)
            .fill(Color.blue.opacity(0.1))
            .shadow(radius: 5)

          VStack {
            Text(isFlipped ? "💡 答案" : "❓ 問題")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding()

            Spacer()

            Text(isFlipped ? shuffledCards[currentCardIndex].content : shuffledCards[currentCardIndex].title)
              .font(.title)
              .bold()
              .multilineTextAlignment(.center)
              .padding()
            // 翻轉時文字動畫
              .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0.0, y: 1.0, z: 0.0)
              )

            Spacer()
          }
        }
        .frame(height: 400)
        .padding()
        .onTapGesture {
          withAnimation(.spring()) {
            isFlipped.toggle()
          }
        }
        .rotation3DEffect(
          .degrees(isFlipped ? 180 : 0),
          axis: (x: 0.0, y: 1.0, z: 0.0)
        )

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
    .onAppear {
      // 進入畫面時，將資料庫的卡片洗牌
      shuffledCards = cards.shuffled()
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
}
