// ChallengeDetailView.swift
// 非同步挑戰：接受挑戰、進行「四選一選擇題」測驗、顯示雙方比對結果

import SwiftUI

// MARK: - MCQQuestion（內部用，不需 Codable）

private struct MCQQuestion: Identifiable {
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

// MARK: - ChallengeDetailView

struct ChallengeDetailView: View {
  let challengeId: UUID

  @EnvironmentObject private var authService: AuthService
  @EnvironmentObject private var experienceStore: ExperienceStore
  @EnvironmentObject private var pendingChallengeStore: PendingChallengeStore

  // 載入狀態
  @State private var isLoading = true
  @State private var errorMessage: String?

  // 挑戰資料
  @State private var challenge: ChallengeSession?
  @State private var challengeCards: [ChallengeCard] = []

  // 測驗狀態
  @State private var showQuiz = false
  @State private var quizResult: (score: Int, total: Int, timeSpent: TimeInterval, combo: Int)?

  // 提交後的最終結果
  @State private var isSubmitting = false
  @State private var finalChallenge: ChallengeSession?
  @State private var showResultAnimation = false

  // EXP 已發放防重複
  @State private var didGrantExp = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()

        if isLoading {
          loadingView
        } else if let error = errorMessage {
          errorView(message: error)
        } else if let challenge {
          mainContent(challenge: challenge)
        }
      }
      .navigationTitle("挑戰詳情")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("關閉") { pendingChallengeStore.clear() }
        }
      }
    }
    .task { await loadChallenge() }
    // 強制四選一模式：以 ChallengeMultipleChoiceQuizView 取代舊版閃卡翻面
    .fullScreenCover(isPresented: $showQuiz) {
      if !challengeCards.isEmpty {
        ChallengeMultipleChoiceQuizView(cards: challengeCards) { score, total, timeSpent, combo in
          quizResult = (score, total, timeSpent, combo)
          showQuiz = false
          Task { await submitResult(score: score, total: total, timeSpent: timeSpent, combo: combo) }
        }
        .environmentObject(authService)
      }
    }
  }

  // MARK: - Loading

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("載入挑戰中…").foregroundStyle(.secondary)
    }
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 48))
        .foregroundStyle(.orange)
      Text(message)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      Button("重新載入") { Task { await loadChallenge() } }
        .buttonStyle(.bordered)
    }
    .padding()
  }

  // MARK: - Main Content

  @ViewBuilder
  private func mainContent(challenge: ChallengeSession) -> some View {
    if let final = finalChallenge ?? (challenge.isCompleted ? challenge : nil) {
      resultView(challenge: final)
    } else if challenge.isEffectivelyExpired {
      expiredView(challenge: challenge)
    } else {
      pendingView(challenge: challenge)
    }
  }

  // MARK: - Pending（等待接受）

  private func pendingView(challenge: ChallengeSession) -> some View {
    ScrollView {
      VStack(spacing: 24) {
        // 挑戰者資訊卡
        challengerCard(challenge: challenge)

        // 選擇題模式說明 badge
        HStack(spacing: 8) {
          Image(systemName: "checkmark.square.fill")
            .foregroundStyle(.orange)
          Text("這是一場四選一選擇題挑戰")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)

        // 單字集資訊
        wordSetCard(challenge: challenge)

        // 接受挑戰按鈕
        VStack(spacing: 12) {
          if challengeCards.isEmpty && challenge.wordSetId != nil {
            Button(action: { Task { await loadCards(challenge: challenge) } }) {
              Label("載入題目", systemImage: "arrow.down.circle")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal)
          } else if !challengeCards.isEmpty {
            Button(action: { showQuiz = true }) {
              Label("開始挑戰（\(challengeCards.count) 題）", systemImage: "flag.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accentColor)
                .cornerRadius(16)
            }
            .padding(.horizontal)
          } else {
            Text("此挑戰的單字集已被刪除，無法進行測驗。")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding()
          }
        }
        .padding(.top, 8)
      }
      .padding(.vertical, 24)
    }
  }

  // MARK: - Result（比較雙方成績）

  private func resultView(challenge: ChallengeSession) -> some View {
    ScrollView {
      VStack(spacing: 24) {
        resultBanner(challenge: challenge)
        scoreComparisonCard(challenge: challenge)

        Button(action: { pendingChallengeStore.clear() }) {
          Text("完成")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accentColor)
            .cornerRadius(16)
        }
        .padding(.horizontal)
      }
      .padding(.vertical, 24)
    }
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        showResultAnimation = true
      }
      grantChallengeExp(challenge: challenge)
    }
  }

  // MARK: - Expired

  private func expiredView(challenge: ChallengeSession) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "clock.badge.xmark")
        .font(.system(size: 56))
        .foregroundStyle(.secondary)
      Text("挑戰已過期")
        .font(.title2.bold())
      Text("這個挑戰已超過 7 天期限，無法再進行。")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
  }

  // MARK: - Sub-components

  private func challengerCard(challenge: ChallengeSession) -> some View {
    VStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(Color.accentColor.opacity(0.15))
          .frame(width: 72, height: 72)
        Text(String(challenge.challengerDisplayName?.prefix(1) ?? "?"))
          .font(.system(size: 32, weight: .bold))
          .foregroundStyle(Color.accentColor)
      }

      Text("\(challenge.challengerDisplayName ?? "某人") 向你發起了挑戰！")
        .font(.title3.bold())
        .multilineTextAlignment(.center)

      HStack(spacing: 4) {
        Image(systemName: "star.fill").foregroundStyle(.yellow)
        Text("Lv.\(challenge.challengerLevel)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        scoreTag(score: challenge.challengerScore,
                 total: challenge.challengerTotal,
                 color: .blue,
                 label: "對方分數")
        if let combo = challenge.challengerCombo, combo > 0 {
          scoreTag(score: combo, total: challenge.challengerTotal, color: .orange, label: "最高連答")
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
    .padding(.horizontal)
  }

  private func wordSetCard(challenge: ChallengeSession) -> some View {
    HStack {
      Image(systemName: "rectangle.stack.fill")
        .font(.title2)
        .foregroundStyle(Color.accentColor)
      VStack(alignment: .leading, spacing: 2) {
        Text("挑戰單字集")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(challenge.wordSetTitle)
          .font(.headline)
      }
      Spacer()
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
    .padding(.horizontal)
  }

  private func resultBanner(challenge: ChallengeSession) -> some View {
    let result = challenge.resultForRespondent()
    let (icon, title, color): (String, String, Color) = {
      switch result {
      case .won:   return ("trophy.fill",  "你贏了！🎉", .yellow)
      case .lost:  return ("xmark.circle.fill", "這次輸了", .red)
      case .tied:  return ("equal.circle.fill", "平手！", .blue)
      case .none:  return ("checkmark.circle.fill", "挑戰完成", .green)
      }
    }()

    return VStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 64))
        .foregroundStyle(color)
        .scaleEffect(showResultAnimation ? 1.0 : 0.5)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showResultAnimation)
      Text(title)
        .font(.system(size: 28, weight: .bold))
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(color.opacity(0.1))
    .cornerRadius(16)
    .padding(.horizontal)
  }

  private func scoreComparisonCard(challenge: ChallengeSession) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text("成績比較")
          .font(.headline)
        Spacer()
        // 選擇題模式標記
        Label("選擇題", systemImage: "checkmark.square")
          .font(.caption)
          .foregroundStyle(.orange)
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 12)

      Divider().padding(.horizontal)

      HStack(spacing: 0) {
        // 挑戰者欄
        VStack(spacing: 6) {
          Text(challenge.challengerDisplayName ?? "對方")
            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
          Text("\(challenge.challengerScore)/\(challenge.challengerTotal)")
            .font(.title2.bold())
          Text("\(challenge.challengerAccuracy)%")
            .font(.caption).foregroundStyle(.secondary)
          if let t = challenge.challengerTimeSpent {
            Text(String(format: "%.0f 秒", t))
              .font(.caption2).foregroundStyle(.secondary)
          }
          if let c = challenge.challengerCombo, c > 0 {
            Label("\(c) 連答", systemImage: "bolt.fill")
              .font(.caption2).foregroundStyle(.orange)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)

        Divider()

        // 接受者欄
        VStack(spacing: 6) {
          Text("你")
            .font(.subheadline).foregroundStyle(.secondary)
          if let rScore = challenge.respondentScore, let rTotal = challenge.respondentTotal {
            Text("\(rScore)/\(rTotal)")
              .font(.title2.bold())
            Text("\(challenge.respondentAccuracy ?? 0)%")
              .font(.caption).foregroundStyle(.secondary)
            if let t = challenge.respondentTimeSpent {
              Text(String(format: "%.0f 秒", t))
                .font(.caption2).foregroundStyle(.secondary)
            }
            if let c = challenge.respondentCombo, c > 0 {
              Label("\(c) 連答", systemImage: "bolt.fill")
                .font(.caption2).foregroundStyle(.orange)
            }
          } else {
            Text("–").font(.title2.bold())
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
      }
    }
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
    .padding(.horizontal)
  }

  private func scoreTag(score: Int, total: Int, color: Color, label: String) -> some View {
    VStack(spacing: 2) {
      Text(label).font(.caption2).foregroundStyle(.secondary)
      Text("\(score)/\(total)").font(.title3.bold().monospacedDigit()).foregroundStyle(color)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(color.opacity(0.1))
    .cornerRadius(8)
  }

  // MARK: - Data Loading

  private func loadChallenge() async {
    isLoading = true
    errorMessage = nil
    let service = ChallengeService(authService: authService)
    do {
      let ch = try await service.fetchChallenge(id: challengeId)
      challenge = ch
      if let wsId = ch.wordSetId, ch.isPending {
        challengeCards = (try? await service.fetchChallengeCards(wordSetId: wsId)) ?? []
      }
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }

  private func loadCards(challenge: ChallengeSession) async {
    guard let wsId = challenge.wordSetId else { return }
    let service = ChallengeService(authService: authService)
    do {
      challengeCards = try await service.fetchChallengeCards(wordSetId: wsId)
    } catch {
      errorMessage = "無法載入題目：\(error.localizedDescription)"
    }
  }

  // MARK: - Submit Result

  private func submitResult(score: Int, total: Int, timeSpent: TimeInterval, combo: Int) async {
    isSubmitting = true
    let service = ChallengeService(authService: authService)
    do {
      try await service.respondToChallenge(
        challengeId: challengeId,
        score: score,
        total: total,
        timeSpent: timeSpent,
        combo: combo)
      let updated = try await service.fetchChallenge(id: challengeId)
      finalChallenge = updated
    } catch {
      var local = challenge
      local?.respondentScore = score
      local?.respondentTotal = total
      local?.respondentTimeSpent = timeSpent
      local?.respondentCombo = combo
      finalChallenge = local
    }
    isSubmitting = false
  }

  // MARK: - EXP 獎勵

  private func grantChallengeExp(challenge: ChallengeSession) {
    guard !didGrantExp,
          authService.currentUserId == challenge.respondentId else { return }
    let result = challenge.resultForRespondent()
    let exp = result == .won ? 30 : (result == .tied ? 15 : 10)
    experienceStore.addExp(delta: exp)
    didGrantExp = true
  }
}

// MARK: - ChallengeMultipleChoiceQuizView
// 四選一選擇題，取代舊版閃卡翻面模式，帶計時、連答（Combo）追蹤

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
