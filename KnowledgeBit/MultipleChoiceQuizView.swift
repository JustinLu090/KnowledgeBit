// MultipleChoiceQuizView.swift
// 針對單字集的選擇題測驗，依正確性與答題速度給予 KE 分數

import SwiftUI

struct MultipleChoiceQuizView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var energyStore: BattleEnergyStore
  let wordSet: WordSet

  @State private var questions: [Question] = []
  @State private var currentIndex: Int = 0
  @State private var showResult: Bool = false
  @State private var lastStartTime: Date = Date()
  @State private var totalKE: Int = 0
  @State private var perQuestionScores: [Int] = []
  @State private var isFinished: Bool = false

  struct Question: Identifiable, Equatable {
    let id = UUID()
    let prompt: String
    let correct: String
    let choices: [String]
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        if isFinished {
          summaryView
        } else if currentIndex < questions.count {
          quizCard(questions[currentIndex])
        } else {
          ProgressView()
        }
      }
      .padding(20)
      .navigationTitle("對戰測驗")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("結束") { finishQuiz() }
        }
      }
      .onAppear { setupQuestions() }
    }
  }

  private func setupQuestions() {
    let cards = wordSet.cards
    guard !cards.isEmpty else { return }

    // 以卡片內容組題：顯示 title，選 content
    var qs: [Question] = []
    let allContents = cards.map { $0.content }

    for card in cards.shuffled() {
      let correct = card.content
      var pool = Array(allContents.shuffled().prefix(8))
      if !pool.contains(correct) { pool.append(correct) }
      let unique = Array(Set(pool)).shuffled()
      let choices = Array(unique.prefix(4)).shuffled()
      qs.append(Question(prompt: card.title, correct: correct, choices: choices))
    }

    questions = qs
    perQuestionScores = Array(repeating: 0, count: qs.count)
    currentIndex = 0
    isFinished = false
    totalKE = 0
    lastStartTime = Date()
  }

  @ViewBuilder
  private func quizCard(_ q: Question) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("題目 \(currentIndex + 1) / \(questions.count)")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)

      Text(q.prompt)
        .font(.title3.bold())
        .frame(maxWidth: .infinity, alignment: .leading)

      ForEach(q.choices, id: \.self) { choice in
        Button {
          handleAnswer(choice: choice, for: q)
        } label: {
          HStack { Text(choice).frame(maxWidth: .infinity, alignment: .leading) }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
      }

      Spacer(minLength: 0)
    }
  }

  private func handleAnswer(choice: String, for q: Question) {
    let elapsed = Date().timeIntervalSince(lastStartTime)
    let correct = (choice == q.correct)
    let score = scoreForQuestion(correct: correct, elapsed: elapsed)

    perQuestionScores[currentIndex] = score
    totalKE += score

    // 下一題
    if currentIndex + 1 < questions.count {
      currentIndex += 1
      lastStartTime = Date()
    } else {
      finishQuiz()
    }
  }

  private func finishQuiz() {
    isFinished = true
  }

  private var summaryView: some View {
    VStack(spacing: 16) {
      Text("測驗完成")
        .font(.title2.bold())
      Text("本次獲得 KE：\(totalKE)")
        .font(.headline)

      HStack(spacing: 12) {
        Button {
          // 將分數寫入 KE 倉儲
          energyStore.addKE(totalKE)
          dismiss()
        } label: {
          Text("存入 KE 並返回")
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)

        NavigationLink {
          BattleView()
        } label: {
          Text("前往對戰模式")
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
      }

      Button("再測一次") {
        setupQuestions()
      }
      .padding(.top, 4)
    }
  }

  private func scoreForQuestion(correct: Bool, elapsed: Double) -> Int {
    guard correct else { return 0 }
    let base = 10
    let fullBonusTime = 3.0
    let maxBonusTime = 8.0
    let bonus: Int
    if elapsed <= fullBonusTime { bonus = 10 }
    else if elapsed >= maxBonusTime { bonus = 0 }
    else {
      let ratio = (elapsed - fullBonusTime) / (maxBonusTime - fullBonusTime)
      bonus = max(0, 10 - Int(ratio * 10))
    }
    return base + bonus
  }
}
