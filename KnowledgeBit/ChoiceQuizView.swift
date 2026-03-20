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
  @State private var showExitConfirmation = false
  /// 每題選項順序（onAppear 時打亂一次，避免正確答案總在同一位置）
  @State private var shuffledOptionsPerQuestion: [[String]] = []

  private var currentQuestion: ChoiceQuestion? {
    guard currentIndex >= 0, currentIndex < questions.count else { return nil }
    return questions[currentIndex]
  }

  /// 將 sentence_with_blank 的 ___ 換成視覺空白
  private func displaySentence(_ raw: String) -> String {
    let pattern = #"(?:_+\s*)+"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return raw.replacingOccurrences(of: "___", with: "__________")
    }

    let range = NSRange(raw.startIndex..., in: raw)
    let collapsed = regex.stringByReplacingMatches(
      in: raw,
      options: [],
      range: range,
      withTemplate: " __________ "
    )
    return collapsed.replacingOccurrences(of: "  ", with: " ")
  }

  private func optionsForCurrentQuestion() -> [String] {
    guard currentIndex >= 0, currentIndex < shuffledOptionsPerQuestion.count else { return [] }
    return shuffledOptionsPerQuestion[currentIndex]
  }

  private var progressValue: Double {
    guard !questions.isEmpty else { return 0 }
    return Double(currentIndex + (showResult ? 1 : 0)) / Double(questions.count)
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
        ZStack {
          LinearGradient(
            colors: [
              Color(.systemBackground),
              Color.blue.opacity(0.05),
              Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .ignoresSafeArea()

          VStack(spacing: 0) {
            quizHeader

            ScrollView(showsIndicators: false) {
              VStack(spacing: 20) {
                questionCard(q)

                VStack(spacing: 12) {
                  let options = optionsForCurrentQuestion()
                  ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    optionButton(
                      option: option,
                      optionIndex: index,
                      correctAnswer: q.correct_answer
                    )
                  }
                }

                if hasAnswered, let explanation = q.explanation, !explanation.isEmpty {
                  explanationCard(explanation)
                }
              }
              .padding(.horizontal, 20)
              .padding(.top, 20)
              .padding(.bottom, 24)
            }

            if hasAnswered {
              bottomActionBar(
                title: currentIndex < questions.count - 1 ? "下一題" : "看結果",
                action: goToNext
              )
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
      if shuffledOptionsPerQuestion.isEmpty {
        shuffledOptionsPerQuestion = questions.map { $0.options.shuffled() }
      }
    }
  }

  @ViewBuilder
  private func optionButton(option: String, optionIndex: Int, correctAnswer: String) -> some View {
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
      HStack(spacing: 14) {
        ZStack {
          Circle()
            .fill(badgeBackgroundColor(showCorrect: showCorrect, showWrong: showWrong, isSelected: isSelected))
          Text(optionBadgeText(optionIndex))
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(badgeForegroundColor(showCorrect: showCorrect, showWrong: showWrong, isSelected: isSelected))
        }
        .frame(width: 34, height: 34)

        Text(option)
          .font(.system(size: 20, weight: .medium))
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        if hasAnswered {
          Image(systemName: showCorrect ? "checkmark.circle.fill" : (showWrong ? "xmark.circle.fill" : "circle"))
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(showCorrect ? .green : (showWrong ? .red : Color.secondary.opacity(0.35)))
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(optionBackground(showCorrect: showCorrect, showWrong: showWrong, isSelected: isSelected))
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(optionBorderColor(showCorrect: showCorrect, showWrong: showWrong, isSelected: isSelected), lineWidth: 1.5)
      )
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
    .disabled(hasAnswered)
  }

  private var quizHeader: some View {
    VStack(spacing: 16) {
      HStack {
        Button {
          if currentIndex > 0 || hasAnswered {
            showExitConfirmation = true
          } else {
            dismiss()
          }
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.blue)
            .frame(width: 44, height: 44)
            .background(Color.blue.opacity(0.10), in: Circle())
        }
        .buttonStyle(.plain)

        Spacer()

        Text("第 \(currentIndex + 1) / \(questions.count) 題")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(Color(.secondarySystemBackground), in: Capsule())

        Spacer()

        Color.clear
          .frame(width: 44, height: 44)
      }

      ProgressView(value: progressValue)
        .tint(.blue)
        .scaleEffect(x: 1, y: 1.8, anchor: .center)
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
    .padding(.bottom, 16)
    .background(.ultraThinMaterial)
  }

  private func questionCard(_ q: ChoiceQuestion) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("填空題")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.12), in: Capsule())

      Text(displaySentence(q.sentence_with_blank))
        .font(.system(size: 27, weight: .semibold))
        .tracking(-0.4)
        .multilineTextAlignment(.leading)
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
    )
  }

  private func explanationCard(_ explanation: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("詳解", systemImage: "lightbulb.fill")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(.orange)
      Text(explanation)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color.orange.opacity(0.10))
    )
  }

  private func bottomActionBar(title: String, action: @escaping () -> Void) -> some View {
    VStack(spacing: 0) {
      Divider()
        .opacity(0.4)
      Button(action: action) {
        Text(title)
          .font(.system(size: 17, weight: .bold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(
            LinearGradient(
              colors: [Color.blue, Color.blue.opacity(0.82)],
              startPoint: .leading,
              endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
          )
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 20)
    }
    .background(.ultraThinMaterial)
  }

  private func optionBadgeText(_ index: Int) -> String {
    ["A", "B", "C", "D"][safe: index] ?? "\(index + 1)"
  }

  private func optionBackground(showCorrect: Bool, showWrong: Bool, isSelected: Bool) -> Color {
    if showCorrect { return Color.green.opacity(0.13) }
    if showWrong { return Color.red.opacity(0.12) }
    if isSelected { return Color.blue.opacity(0.10) }
    return Color(.secondarySystemBackground)
  }

  private func optionBorderColor(showCorrect: Bool, showWrong: Bool, isSelected: Bool) -> Color {
    if showCorrect { return Color.green.opacity(0.55) }
    if showWrong { return Color.red.opacity(0.45) }
    if isSelected { return Color.blue.opacity(0.45) }
    return Color.black.opacity(0.05)
  }

  private func badgeBackgroundColor(showCorrect: Bool, showWrong: Bool, isSelected: Bool) -> Color {
    if showCorrect { return .green }
    if showWrong { return .red }
    if isSelected { return .blue }
    return Color(.tertiarySystemFill)
  }

  private func badgeForegroundColor(showCorrect: Bool, showWrong: Bool, isSelected: Bool) -> Color {
    if showCorrect || showWrong || isSelected { return .white }
    return .secondary
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

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
