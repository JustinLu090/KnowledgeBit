// ChoiceQuizView.swift
// 選擇題測驗：挖空句 + 四選一，依題逐題作答後顯示結果

import SwiftUI

struct ChoiceQuizView: View {
  let questions: [ChoiceQuestion]
  let onFinish: (Int, Int) -> Void

  @Environment(\.dismiss) var dismiss
  @State private var currentIndex = 0
  @State private var score = 0
  @State private var selectedOption: String?
  @State private var hasAnswered = false
  @State private var showResult = false
  /// 每題選項順序（onAppear 時打亂一次，避免正確答案總在同一位置）
  @State private var shuffledOptionsPerQuestion: [[String]] = []

  private var currentQuestion: ChoiceQuestion? {
    guard currentIndex >= 0, currentIndex < questions.count else { return nil }
    return questions[currentIndex]
  }

  /// 將 sentence_with_blank 的 ___ 換成視覺空白
  private func displaySentence(_ raw: String) -> String {
    raw.replacingOccurrences(of: "___", with: " ______ ")
  }

  private func optionsForCurrentQuestion() -> [String] {
    guard currentIndex >= 0, currentIndex < shuffledOptionsPerQuestion.count else { return [] }
    return shuffledOptionsPerQuestion[currentIndex]
  }

  var body: some View {
    Group {
      if showResult {
        QuizResultView(
          rememberedCards: score,
          totalCards: questions.count,
          streakDays: nil,
          onFinish: {
            onFinish(score, questions.count)
            dismiss()
          },
          onRetry: {
            showResult = false
            currentIndex = 0
            score = 0
            selectedOption = nil
            hasAnswered = false
          }
        )
      } else if let q = currentQuestion {
        VStack(spacing: 24) {
          Text("第 \(currentIndex + 1) / \(questions.count) 題")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)

          Text(displaySentence(q.sentence_with_blank))
            .font(.title2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)

          VStack(spacing: 12) {
            ForEach(optionsForCurrentQuestion(), id: \.self) { option in
              optionButton(option: option, correctAnswer: q.correct_answer)
            }
          }
          .padding(.horizontal, 20)

          if hasAnswered {
            Button(action: goToNext) {
              Text(currentIndex < questions.count - 1 ? "下一題" : "看結果")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
          }

          Spacer()
        }
      }
    }
    .onAppear {
      if shuffledOptionsPerQuestion.isEmpty {
        shuffledOptionsPerQuestion = questions.map { $0.options.shuffled() }
      }
    }
  }

  @ViewBuilder
  private func optionButton(option: String, correctAnswer: String) -> some View {
    let isSelected = selectedOption == option
    let isCorrect = option == correctAnswer
    let showCorrect = hasAnswered && isCorrect
    let showWrong = hasAnswered && isSelected && !isCorrect

    Button {
      if !hasAnswered {
        selectedOption = option
        hasAnswered = true
        if isCorrect { score += 1 }
      }
    } label: {
      Text(option)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundColor(showCorrect: showCorrect, showWrong: showWrong, isSelected: isSelected))
        .foregroundColor(foregroundColor(showCorrect: showCorrect, showWrong: showWrong))
        .cornerRadius(10)
    }
    .disabled(hasAnswered)
  }

  private func backgroundColor(showCorrect: Bool, showWrong: Bool, isSelected: Bool) -> Color {
    if showCorrect { return Color.green.opacity(0.25) }
    if showWrong { return Color.red.opacity(0.25) }
    if isSelected { return Color.blue.opacity(0.15) }
    return Color(.secondarySystemFill)
  }

  private func foregroundColor(showCorrect: Bool, showWrong: Bool) -> Color {
    if showCorrect || showWrong { return .primary }
    return .primary
  }

  private func goToNext() {
    if currentIndex < questions.count - 1 {
      currentIndex += 1
      selectedOption = nil
      hasAnswered = false
    } else {
      showResult = true
    }
  }
}
