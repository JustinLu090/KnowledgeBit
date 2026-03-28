// ChallengeDetailView.swift
// 非同步挑戰：接受挑戰、進行測驗、顯示雙方比對結果

import SwiftUI

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
  @State private var quizResult: (score: Int, total: Int, timeSpent: TimeInterval)?

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
    // 測驗完成後的全螢幕覆蓋
    .fullScreenCover(isPresented: $showQuiz) {
      if !challengeCards.isEmpty {
        ChallengeQuizView(cards: challengeCards) { score, total, timeSpent in
          quizResult = (score, total, timeSpent)
          showQuiz = false
          Task { await submitResult(score: score, total: total, timeSpent: timeSpent) }
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

        // 單字集資訊
        wordSetCard(challenge: challenge)

        // 接受挑戰按鈕
        VStack(spacing: 12) {
          if challengeCards.isEmpty && challenge.wordSetId != nil {
            // 卡片未載入
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
              Label("接受挑戰（\(challengeCards.count) 題）", systemImage: "flag.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accentColor)
                .cornerRadius(16)
            }
            .padding(.horizontal)
          } else {
            // wordSetId 為 nil，無法取得題目
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
        // 結果 Banner
        resultBanner(challenge: challenge)

        // 雙方成績對比
        scoreComparisonCard(challenge: challenge)

        // 關閉按鈕
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
      // 頭像佔位
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

      // 挑戰者分數預覽
      HStack(spacing: 8) {
        scoreTag(score: challenge.challengerScore,
                 total: challenge.challengerTotal,
                 color: .blue,
                 label: "對方分數")
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
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 12)

      Divider().padding(.horizontal)

      HStack(spacing: 0) {
        // 挑戰者欄
        VStack(spacing: 6) {
          Text(challenge.challengerDisplayName ?? "對方")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text("\(challenge.challengerScore)/\(challenge.challengerTotal)")
            .font(.title2.bold())
          Text("\(challenge.challengerAccuracy)%")
            .font(.caption)
            .foregroundStyle(.secondary)
          if let t = challenge.challengerTimeSpent {
            Text(String(format: "%.0f 秒", t))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)

        Divider()

        // 接受者欄
        VStack(spacing: 6) {
          Text("你")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          if let rScore = challenge.respondentScore, let rTotal = challenge.respondentTotal {
            Text("\(rScore)/\(rTotal)")
              .font(.title2.bold())
            Text("\(challenge.respondentAccuracy ?? 0)%")
              .font(.caption)
              .foregroundStyle(.secondary)
            if let t = challenge.respondentTimeSpent {
              Text(String(format: "%.0f 秒", t))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          } else {
            Text("–")
              .font(.title2.bold())
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
      Text("\(score)/\(total)").font(.title3.bold().monospacedDigit()
      ).foregroundStyle(color)
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
      // 若有 wordSetId，預先載入卡片
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

  private func submitResult(score: Int, total: Int, timeSpent: TimeInterval) async {
    isSubmitting = true
    let service = ChallengeService(authService: authService)
    do {
      try await service.respondToChallenge(
        challengeId: challengeId,
        score: score,
        total: total,
        timeSpent: timeSpent)
      // 重新讀取最新資料，填入 respondent 欄位
      let updated = try await service.fetchChallenge(id: challengeId)
      finalChallenge = updated
    } catch {
      // 即使上傳失敗，仍顯示本地分數
      var local = challenge
      local?.respondentScore = score
      local?.respondentTotal = total
      local?.respondentTimeSpent = timeSpent
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

// MARK: - ChallengeQuizView
// 輕量測驗視圖，接受 [ChallengeCard]，完成後回呼成績

struct ChallengeQuizView: View {
  let cards: [ChallengeCard]
  let onFinish: (Int, Int, TimeInterval) -> Void

  @State private var shuffled: [ChallengeCard] = []
  @State private var currentIndex = 0
  @State private var isFlipped = false
  @State private var score = 0
  @State private var startTime = Date()
  @State private var showExitAlert = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack {
        // 進度
        Text("Question \(currentIndex + 1) / \(shuffled.count)")
          .font(.caption).foregroundStyle(.secondary).padding(.top)

        Spacer()

        if shuffled.isEmpty {
          Text("沒有卡片").foregroundStyle(.secondary)
        } else {
          challengeCard
        }

        Spacer()
        bottomButtons
      }
      .navigationTitle(cards.isEmpty ? "挑戰" : "挑戰測驗")
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
      shuffled = cards.shuffled()
      startTime = Date()
    }
  }

  // MARK: - Card

  private var challengeCard: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.blue.opacity(0.1))
        .shadow(radius: 5)

      VStack {
        Text(isFlipped ? "💡 答案" : "❓ 問題")
          .font(.caption).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading).padding()
        Spacer()
        Text(isFlipped ? shuffled[currentIndex].content : shuffled[currentIndex].title)
          .font(.title).bold().multilineTextAlignment(.center).padding()
        Spacer()
      }
    }
    .frame(height: 360)
    .padding()
    .onTapGesture {
      withAnimation(.spring()) { isFlipped.toggle() }
    }
    .animation(.spring(), value: isFlipped)
  }

  // MARK: - Buttons

  @ViewBuilder
  private var bottomButtons: some View {
    if isFlipped {
      HStack(spacing: 40) {
        actionButton(isCorrect: false)
        actionButton(isCorrect: true)
      }
      .padding(.bottom, 50)
    } else {
      Text("點擊卡片查看答案")
        .foregroundStyle(.secondary)
        .padding(.bottom, 50)
    }
  }

  private func actionButton(isCorrect: Bool) -> some View {
    Button(action: { nextCard(isCorrect: isCorrect) }) {
      VStack {
        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
          .font(.system(size: 50))
          .foregroundStyle(isCorrect ? .green : .red)
        Text(isCorrect ? "記住了" : "忘了")
          .font(.caption)
      }
    }
  }

  private func nextCard(isCorrect: Bool) {
    if isCorrect { score += 1 }
    withAnimation {
      if currentIndex < shuffled.count - 1 {
        isFlipped = false
        currentIndex += 1
      } else {
        let elapsed = Date().timeIntervalSince(startTime)
        onFinish(score, shuffled.count, elapsed)
      }
    }
  }
}
