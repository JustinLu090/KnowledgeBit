// ChallengeDetailViewModel.swift
// 非同步挑戰詳情 ViewModel：負責載入、提交、發放 EXP；UI 透過 @Published 訂閱狀態。
//
// 依賴透過 init 注入（service / currentUserId / grantExp / rewardedStore），
// 方便在測試中以 mock 取代而無需建立真的 AuthService / ExperienceStore。

import Foundation
import SwiftUI
import Combine
import os

@MainActor
final class ChallengeDetailViewModel: ObservableObject {
  // MARK: - Published State

  /// 初始載入狀態。完成後才顯示主內容。
  @Published private(set) var isLoading = true

  /// 阻斷型錯誤（初始 fetchChallenge 失敗）：UI 切換成「重新載入」畫面。
  @Published var loadError: String?

  /// 過渡型錯誤（載入題目、提交結果失敗）：透過 .handleAppError 顯示頂部 Banner。
  @Published var errorMessage: String?

  /// 挑戰主資料。
  @Published private(set) var challenge: ChallengeSession?

  /// 路徑 A：以單字集卡片動態產生 MCQ。
  @Published private(set) var challengeCards: [ChallengeCard] = []

  /// 路徑 B：AI 預先生成的選擇題快照（雙方看到完全相同題目）。
  @Published private(set) var quizContent: [ChoiceQuestion] = []

  /// 提交成功後的最新挑戰物件；UI 優先以此為準渲染結果頁。
  @Published private(set) var finalChallenge: ChallengeSession?

  /// 內部重入保護旗標：避免使用者快速點擊重複提交。
  private var isSubmitting = false

  // MARK: - Dependencies

  private let service: ChallengeServicing
  private let currentUserId: () -> UUID?
  private let grantExp: (Int) -> Void
  private let rewardedStore: RewardedChallengeStore
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.knowledgebit",
    category: "Challenge"
  )

  init(
    service: ChallengeServicing,
    currentUserId: @escaping () -> UUID?,
    grantExp: @escaping (Int) -> Void,
    rewardedStore: RewardedChallengeStore? = nil
  ) {
    self.service = service
    self.currentUserId = currentUserId
    self.grantExp = grantExp
    self.rewardedStore = rewardedStore ?? RewardedChallengeStore()
  }

  // MARK: - Derived

  /// 結果頁應使用的挑戰物件（沿用原 View 邏輯：finalChallenge ?? (challenge.isCompleted ? challenge : nil)）。
  var resultChallenge: ChallengeSession? {
    if let final = finalChallenge { return final }
    if let ch = challenge, ch.isCompleted { return ch }
    return nil
  }

  // MARK: - Load

  func load(challengeId: UUID) async {
    isLoading = true
    loadError = nil
    do {
      let ch = try await service.fetchChallenge(id: challengeId)
      challenge = ch
      if ch.isPending {
        if let content = ch.quizContent, !content.isEmpty {
          quizContent = content
          logger.debug("Using cached AI quiz content for challenge: \(challengeId, privacy: .public)")
        } else if let fixedIds = ch.shuffledCardIds, !fixedIds.isEmpty {
          challengeCards = (try? await service.fetchChallengeCardsByIds(fixedIds)) ?? []
        } else if let wsId = ch.wordSetId {
          challengeCards = (try? await service.fetchChallengeCards(wordSetId: wsId)) ?? []
        }
      }
    } catch {
      loadError = AppError.networkError(error).errorDescription
    }
    isLoading = false
  }

  /// 路徑 A 的延後載入：使用者點「載入題目」時觸發。
  func loadCards() async {
    guard let ch = challenge else { return }
    do {
      if let fixedIds = ch.shuffledCardIds, !fixedIds.isEmpty {
        challengeCards = try await service.fetchChallengeCardsByIds(fixedIds)
      } else if let wsId = ch.wordSetId {
        challengeCards = try await service.fetchChallengeCards(wordSetId: wsId)
      }
    } catch {
      errorMessage = AppError.networkError(error).errorDescription
    }
  }

  // MARK: - Submit

  func submitResult(
    challengeId: UUID,
    score: Int,
    total: Int,
    timeSpent: TimeInterval,
    combo: Int
  ) async {
    guard !isSubmitting else { return }
    isSubmitting = true
    defer { isSubmitting = false }

    do {
      try await service.respondToChallenge(
        challengeId: challengeId,
        score: score,
        total: total,
        timeSpent: timeSpent,
        combo: combo
      )
      let updated = try await service.fetchChallenge(id: challengeId)
      finalChallenge = updated
    } catch {
      // 伺服器同步失敗：以本機暫存結果讓 UI 仍能呈現，並透過 banner 通知使用者。
      var local = challenge
      local?.respondentScore = score
      local?.respondentTotal = total
      local?.respondentTimeSpent = timeSpent
      local?.respondentCombo = combo
      finalChallenge = local
      errorMessage = AppError.networkError(error).errorDescription
      logger.error("Submit challenge result failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - EXP

  /// 結果頁顯示時呼叫。透過 RewardedChallengeStore 防止跨 Session 重複發放、自動 FIFO 淘汰。
  func grantChallengeExp() {
    guard let challenge = resultChallenge else { return }
    guard currentUserId() == challenge.respondentId,
          !rewardedStore.contains(challenge.id) else { return }
    let exp: Int = {
      switch challenge.resultForRespondent() {
      case .won: return ChallengeRewards.win
      case .tied: return ChallengeRewards.tie
      default: return ChallengeRewards.lose
      }
    }()
    grantExp(exp)
    rewardedStore.record(challenge.id)
    logger.info("Granted \(exp) EXP for challenge \(challenge.id.uuidString, privacy: .public)")
  }
}
