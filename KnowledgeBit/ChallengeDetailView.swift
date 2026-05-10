// ChallengeDetailView.swift
// 非同步挑戰：接受挑戰、進行「四選一選擇題」測驗、顯示雙方比對結果。
// 業務邏輯位於 ChallengeDetailViewModel；本檔僅負責 UI 呈現。
//
// Outer ChallengeDetailView 從 environment 取得 authService / experienceStore，
// 透過 init 注入給 inner ChallengeDetailContent，後者建構 ViewModel 與其 service。

import SwiftUI

struct ChallengeDetailView: View {
  let challengeId: UUID

  @EnvironmentObject private var authService: AuthService
  @EnvironmentObject private var experienceStore: ExperienceStore

  var body: some View {
    ChallengeDetailContent(
      challengeId: challengeId,
      authService: authService,
      experienceStore: experienceStore
    )
  }
}

private struct ChallengeDetailContent: View {
  let challengeId: UUID
  let authService: AuthService
  let experienceStore: ExperienceStore

  @Environment(\.dismiss) private var dismiss
  @StateObject private var vm: ChallengeDetailViewModel

  // 測驗 UI 流程旗標（純 View 層狀態）
  @State private var showQuiz = false         // 卡片式 MCQ
  @State private var showChoiceQuiz = false   // AI 快照式選擇題
  @State private var choiceQuizStartTime = Date()

  // 結果頁動畫狀態
  @State private var showResultAnimation = false
  @State private var showConfetti = false

  init(challengeId: UUID, authService: AuthService, experienceStore: ExperienceStore) {
    self.challengeId = challengeId
    self.authService = authService
    self.experienceStore = experienceStore
    _vm = StateObject(wrappedValue: ChallengeDetailViewModel(
      service: ChallengeService(authService: authService),
      currentUserId: { authService.currentUserId },
      grantExp: { delta in experienceStore.addExp(delta: delta) }
    ))
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()

        if vm.isLoading {
          loadingView
        } else if let error = vm.loadError {
          errorView(message: error)
        } else if let challenge = vm.challenge {
          mainContent(challenge: challenge)
        }
      }
      .navigationTitle("挑戰詳情")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("關閉") { dismiss() }
        }
      }
      .handleAppError($vm.errorMessage)
    }
    .task { await vm.load(challengeId: challengeId) }
    // 路徑 A：卡片式 MCQ（無 quiz_content 時的 fallback）
    .fullScreenCover(isPresented: $showQuiz) {
      if !vm.challengeCards.isEmpty {
        ChallengeMultipleChoiceQuizView(cards: vm.challengeCards) { score, total, timeSpent, combo in
          showQuiz = false
          Task {
            await vm.submitResult(
              challengeId: challengeId,
              score: score,
              total: total,
              timeSpent: timeSpent,
              combo: combo
            )
          }
        }
        .environmentObject(authService)
      }
    }
    // 路徑 B：AI 快照題目（quiz_content 存在時，B 看到與 A 完全相同的題目）
    .fullScreenCover(isPresented: $showChoiceQuiz) {
      if !vm.quizContent.isEmpty {
        ChoiceQuizView(
          questions: vm.quizContent,
          onFinish: { score, total in
            let elapsed = Date().timeIntervalSince(choiceQuizStartTime)
            showChoiceQuiz = false
            Task {
              await vm.submitResult(
                challengeId: challengeId,
                score: score,
                total: total,
                timeSpent: elapsed,
                combo: 0
              )
            }
          }
        )
        .environmentObject(authService)
        .environmentObject(experienceStore)
      }
    }
  }

  // MARK: - Loading

  private var loadingView: some View {
    VStack(spacing: 32) {
      ZStack {
        Circle()
          .stroke(Color.accentColor.opacity(0.12), lineWidth: 5)
          .frame(width: 80, height: 80)
        Circle()
          .trim(from: 0, to: 0.7)
          .stroke(
            LinearGradient(colors: [.accentColor, .accentColor.opacity(0.3)],
                           startPoint: .leading, endPoint: .trailing),
            style: StrokeStyle(lineWidth: 5, lineCap: .round)
          )
          .frame(width: 80, height: 80)
          .rotationEffect(.degrees(-90))
          .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: vm.isLoading)
        Image(systemName: "flag.fill")
          .font(.system(size: 24))
          .foregroundStyle(Color.accentColor.opacity(0.7))
      }

      VStack(spacing: 8) {
        Text("載入挑戰中…")
          .font(.title3.bold())
          .foregroundStyle(.primary)
        Text("正在從雲端取得題目快照")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      // 骨架佔位卡
      VStack(spacing: 10) {
        ForEach(0..<3, id: \.self) { i in
          RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemGroupedBackground))
            .frame(height: 52)
            .opacity(vm.isLoading ? Double(3 - i) / 4.0 : 0)
            .animation(
              .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15),
              value: vm.isLoading
            )
        }
      }
      .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 48))
        .foregroundStyle(.orange)
      Text(message)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      Button("重新載入") {
        Task { await vm.load(challengeId: challengeId) }
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }

  // MARK: - Main Content

  @ViewBuilder
  private func mainContent(challenge: ChallengeSession) -> some View {
    if let final = vm.resultChallenge {
      resultView(challenge: final)
    } else if challenge.isEffectivelyExpired {
      expiredView(challenge: challenge)
    } else if challenge.challengerId == authService.currentUserId {
      // 發起者不能接受自己的挑戰
      selfChallengeView(challenge: challenge)
    } else if challenge.respondentId == authService.currentUserId,
              let prevScore = challenge.respondentScore,
              let prevTotal = challenge.respondentTotal {
      // 已挑戰過：顯示紀錄而非再次開始
      alreadyRespondedView(challenge: challenge, score: prevScore, total: prevTotal)
    } else {
      pendingView(challenge: challenge)
    }
  }

  // MARK: - Pending（等待接受）

  private func pendingView(challenge: ChallengeSession) -> some View {
    ScrollView {
      VStack(spacing: 24) {
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

        wordSetCard(challenge: challenge)

        VStack(spacing: 12) {
          if !vm.quizContent.isEmpty {
            // 路徑 B：AI 快照題目直接開始，不需要再載入
            Button(action: {
              choiceQuizStartTime = Date()
              showChoiceQuiz = true
            }) {
              Label("開始挑戰（\(vm.quizContent.count) 題）", systemImage: "flag.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accentColor)
                .cornerRadius(16)
            }
            .padding(.horizontal)
          } else if vm.challengeCards.isEmpty && challenge.wordSetId != nil {
            // 路徑 A：卡片式，需先載入
            Button(action: { Task { await vm.loadCards() } }) {
              Label("載入題目", systemImage: "arrow.down.circle")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal)
          } else if !vm.challengeCards.isEmpty {
            Button(action: { showQuiz = true }) {
              Label("開始挑戰（\(vm.challengeCards.count) 題）", systemImage: "flag.fill")
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
    ZStack {
      ScrollView {
        VStack(spacing: 24) {
          resultBanner(challenge: challenge)
          scoreComparisonCard(challenge: challenge)

          Button(action: { dismiss() }) {
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

      // 紙屑特效層（僅勝出時顯示）
      ConfettiView(isActive: showConfetti)
        .ignoresSafeArea()
    }
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        showResultAnimation = true
      }
      vm.grantChallengeExp()
      // 接受者贏了才觸發紙屑
      if challenge.resultForRespondent() == .won {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
          showConfetti = true
        }
      }
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

  // MARK: - Self Challenge（發起者不能接受自己的挑戰）

  private func selfChallengeView(challenge: ChallengeSession) -> some View {
    VStack(spacing: 20) {
      Image(systemName: "person.fill.questionmark")
        .font(.system(size: 56))
        .foregroundStyle(.secondary)
      Text("這是你自己發起的挑戰")
        .font(.title2.bold())
      Text("分享連結給朋友，等待他們應戰吧！")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      let shareURL = ChallengeService.deepLink(for: challenge.id)
      ShareLink(
        item: shareURL,
        subject: Text("KnowledgeBit 挑戰"),
        message: Text("我在「\(challenge.wordSetTitle)」答對了 \(challenge.challengerScore)/\(challenge.challengerTotal) 題，你能超越我嗎？")
      ) {
        Label("分享挑戰連結", systemImage: "square.and.arrow.up")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(Color.orange)
          .cornerRadius(16)
      }
      .padding(.horizontal)
    }
    .padding(.vertical, 40)
  }

  // MARK: - Already Responded（已挑戰過）

  private func alreadyRespondedView(challenge: ChallengeSession, score: Int, total: Int) -> some View {
    let accuracy = total > 0 ? Int(Double(score) / Double(total) * 100) : 0
    return VStack(spacing: 24) {
      VStack(spacing: 8) {
        Image(systemName: "checkmark.seal.fill")
          .font(.system(size: 56))
          .foregroundStyle(.green)
        Text("你已挑戰過這題！")
          .font(.title2.bold())
        Text("目前最高分為")
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 4) {
        Text("\(score) / \(total)")
          .font(.system(size: 48, weight: .black, design: .rounded))
          .foregroundStyle(.primary)
        Text("正確率 \(accuracy)%")
          .font(.title3)
          .foregroundStyle(accuracy >= 80 ? .green : accuracy >= 50 ? .orange : .red)
      }
      .padding(24)
      .frame(maxWidth: .infinity)
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(20)
      .padding(.horizontal)

      Text("挑戰結果已記錄，無法重複作答。")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Button(action: { dismiss() }) {
        Text("關閉")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(Color.accentColor)
          .cornerRadius(16)
      }
      .padding(.horizontal)
    }
    .padding(.vertical, 40)
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
}
