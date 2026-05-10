// ChallengeMultipleChoiceQuizView.swift
// 非同步挑戰用的四選一選擇題介面（路徑 A：以 ChallengeCard 動態產生 MCQ），
// 帶計時、連答（Combo）追蹤；完成後透過 onFinish 將成績回傳給 ChallengeDetailView。

import SwiftUI

// MARK: - MCQQuestion

/// 內部可見以便單元測試呼叫 makeQuestions(from:)；外部模組仍無法存取（檔案/類別預設 internal）。
struct MCQQuestion: Identifiable {
  let id = UUID()
  let prompt: String          // 問題（卡片正面）
  let correctAnswer: String   // 正確答案（卡片背面）
  let choices: [String]       // 四個選項（已隨機排列）

  /// 從 ChallengeCard 陣列自動產生選擇題（以其他卡片的背面作為干擾項）
  static func makeQuestions(from cards: [ChallengeCard]) -> [MCQQuestion] {
    guard cards.count >= 2 else { return [] }
    return cards.map { card in
      let pool = cards.filter { $0.id != card.id }.map { $0.content }.shuffled()
      // 取最多 3 個干擾項；不足時重複 pool 以填滿
      var distractors: [String] = []
      var used = 0
      while distractors.count < 3 {
        distractors.append(pool[used % pool.count])
        used += 1
      }
      let choices = ([card.content] + distractors).shuffled()
      return MCQQuestion(prompt: card.title, correctAnswer: card.content, choices: choices)
    }.shuffled()
  }
}

// MARK: - ChallengeMultipleChoiceQuizView

struct ChallengeMultipleChoiceQuizView: View {
  let cards: [ChallengeCard]
  /// 完成回呼：(正確數, 總題數, 耗時秒數, 最高連答數)
  let onFinish: (Int, Int, TimeInterval, Int) -> Void

  @State private var questions: [MCQQuestion] = []
  @State private var currentIndex = 0
  @State private var score = 0
  @State private var currentCombo = 0
  @State private var maxCombo = 0
  @State private var startTime = Date()
  @State private var selectedAnswer: String? = nil
  @State private var showFeedback = false
  @State private var showExitAlert = false

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        progressHeader

        if questions.isEmpty {
          Spacer()
          Text("題目不足（至少需要 2 張卡片）")
            .foregroundStyle(.secondary)
          Spacer()
        } else if currentIndex < questions.count {
          questionView(question: questions[currentIndex])
        }
      }
      .background(Color(.systemGroupedBackground).ignoresSafeArea())
      .navigationTitle("選擇題挑戰")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("放棄") { showExitAlert = true }
        }
      }
      .alert("放棄挑戰？", isPresented: $showExitAlert) {
        Button("取消", role: .cancel) {}
        Button("放棄", role: .destructive) { dismiss() }
      } message: {
        Text("放棄後此挑戰將不計成績。")
      }
    }
    .onAppear {
      questions = MCQQuestion.makeQuestions(from: cards)
      startTime = Date()
    }
  }

  // MARK: - Progress Header

  private var progressHeader: some View {
    VStack(spacing: 6) {
      HStack {
        Text("第 \(min(currentIndex + 1, questions.count)) / \(questions.count) 題")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        // Combo 指示
        if currentCombo >= 2 {
          Label("\(currentCombo) 連答！", systemImage: "bolt.fill")
            .font(.caption.bold())
            .foregroundStyle(.orange)
        }
        // 分數
        Text("\(score) 分")
          .font(.caption.bold())
          .foregroundStyle(.primary)
      }
      .padding(.horizontal, 20)

      ProgressView(value: Double(currentIndex), total: Double(max(questions.count, 1)))
        .tint(currentCombo >= 3 ? .orange : .accentColor)
        .padding(.horizontal, 20)
    }
    .padding(.top, 12)
    .padding(.bottom, 8)
  }

  // MARK: - Question View

  @ViewBuilder
  private func questionView(question: MCQQuestion) -> some View {
    ScrollView {
      VStack(spacing: 24) {
        // 問題卡
        VStack(spacing: 12) {
          Text("問題")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(question.prompt)
            .font(.title2.bold())
            .multilineTextAlignment(.center)
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .padding(.horizontal)
        .padding(.top, 8)

        // 選項按鈕
        VStack(spacing: 12) {
          ForEach(question.choices, id: \.self) { choice in
            choiceButton(choice: choice, question: question)
          }
        }
        .padding(.horizontal)
        .disabled(showFeedback)
      }
      .padding(.bottom, 40)
    }
  }

  @ViewBuilder
  private func choiceButton(choice: String, question: MCQQuestion) -> some View {
    let isSelected = selectedAnswer == choice
    let isCorrect = choice == question.correctAnswer
    let bgColor: Color = {
      guard showFeedback && isSelected else { return Color(.secondarySystemGroupedBackground) }
      return isCorrect ? .green.opacity(0.2) : .red.opacity(0.2)
    }()
    let borderColor: Color = {
      guard showFeedback else { return Color.clear }
      if isSelected { return isCorrect ? .green : .red }
      if isCorrect { return .green }  // 顯示正確答案
      return Color.clear
    }()

    Button(action: { selectAnswer(choice, question: question) }) {
      HStack {
        Text(choice)
          .font(.body)
          .multilineTextAlignment(.leading)
          .foregroundStyle(.primary)
        Spacer()
        if showFeedback {
          if isSelected {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
              .foregroundStyle(isCorrect ? .green : .red)
          } else if isCorrect {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
          }
        }
      }
      .padding(16)
      .background(bgColor)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(borderColor, lineWidth: 2)
      )
      .cornerRadius(12)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Logic

  private func selectAnswer(_ answer: String, question: MCQQuestion) {
    guard !showFeedback else { return }
    selectedAnswer = answer
    showFeedback = true

    let isCorrect = answer == question.correctAnswer
    if isCorrect {
      score += 1
      currentCombo += 1
      maxCombo = max(maxCombo, currentCombo)
    } else {
      currentCombo = 0
    }

    // 0.9 秒後自動進入下一題
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
      advance()
    }
  }

  private func advance() {
    selectedAnswer = nil
    showFeedback = false
    if currentIndex < questions.count - 1 {
      withAnimation(.easeInOut(duration: 0.2)) {
        currentIndex += 1
      }
    } else {
      let elapsed = Date().timeIntervalSince(startTime)
      onFinish(score, questions.count, elapsed, maxCombo)
    }
  }
}
