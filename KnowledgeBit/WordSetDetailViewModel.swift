// WordSetDetailViewModel.swift
// 單字集詳情 ViewModel：負責共編成員清單、進行中的對戰狀態、AI 選擇題產生流程。
// UI 呈現旗標（fullScreenCover/sheet 是否顯示）保留在 View。

import Foundation
import SwiftUI
import Combine
import SwiftData
import os

@MainActor
final class WordSetDetailViewModel: ObservableObject {
  // MARK: - Published State

  @Published private(set) var collaborators: [WordSetCollaborator] = []

  @Published private(set) var activeBattleSession: BattleSession?
  @Published private(set) var isLoadingBattleSession = false

  /// AI 選擇題產生流程
  @Published private(set) var generatedQuestions: [ChoiceQuestion]?
  @Published private(set) var quizGenerateError: String?
  @Published private(set) var isGeneratingQuiz = false

  /// 過渡型錯誤（如載入共編 / 載入對戰失敗），透過 .handleAppError 顯示頂部 banner。
  @Published var errorMessage: String?

  // MARK: - Private

  private var quizGenerationTask: Task<Void, Never>?

  init() {}

  // MARK: - Collaborators

  func loadCollaborators(wordSetId: UUID, authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    let service = WordSetCollaboratorService(authService: authService, userId: currentUserId)
    do {
      collaborators = try await service.fetchCollaborators(wordSetId: wordSetId)
    } catch {
      AppLog.wordset.info("⚠️ [WordSet] fetchCollaborators 失敗: \(error)")
      errorMessage = AppError.networkError(error).errorDescription
    }
  }

  func setCollaborators(_ updated: [WordSetCollaborator]) {
    collaborators = updated
  }

  /// 與目前使用者不同的成員（標題列頭像列只顯示「他人」）。
  func otherCollaborators(currentUserId: UUID?) -> [WordSetCollaborator] {
    guard let currentUserId else { return collaborators }
    return collaborators.filter { $0.userId != currentUserId }
  }

  // MARK: - Active Battle

  func loadActiveBattleIfNeeded(wordSetId: UUID, authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    isLoadingBattleSession = true
    defer { isLoadingBattleSession = false }

    let service = BattleRoomService(authService: authService, userId: currentUserId)
    do {
      if let session = try await service.fetchActiveRoom(wordSetID: wordSetId) {
        activeBattleSession = session
      }
    } catch {
      // 使用者快速離開畫面時 task 會被取消，屬於預期行為
      let ns = error as NSError
      if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
      AppLog.wordset.info("⚠️ [WordSet] loadActiveBattleIfNeeded 失敗: \(error)")
      errorMessage = AppError.networkError(error).errorDescription
    }
  }

  // MARK: - Card Sync

  func pullCardsForWordSetIfNeeded(wordSet: WordSet, modelContext: ModelContext, authService: AuthService) async {
    guard let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) else { return }
    await sync.pullCardsForWordSet(wordSet: wordSet, modelContext: modelContext)
  }

  // MARK: - AI Quiz Generation

  /// 啟動 AI 題目產生：先進入 isGeneratingQuiz=true 顯示載入畫面，再以 yield() 確保畫面有繪到。
  func startChoiceQuiz(cards: [Card], wordSet: WordSet, authService: AuthService) {
    isGeneratingQuiz = true
    quizGenerateError = nil
    generatedQuestions = nil
    quizGenerationTask?.cancel()

    Task { @MainActor in
      await Task.yield()
      guard isGeneratingQuiz else { return }
      launchChoiceQuizGeneration(cards: cards, wordSet: wordSet, authService: authService)
    }
  }

  func cancelChoiceQuizGeneration() {
    quizGenerationTask?.cancel()
    quizGenerationTask = nil
    isGeneratingQuiz = false
  }

  /// 結束 AI 題目流程（測驗完成或關閉時呼叫），清空生成狀態。
  func resetChoiceQuizState() {
    quizGenerationTask?.cancel()
    quizGenerationTask = nil
    generatedQuestions = nil
    quizGenerateError = nil
    isGeneratingQuiz = false
  }

  private func launchChoiceQuizGeneration(cards: [Card], wordSet: WordSet, authService: AuthService) {
    quizGenerationTask?.cancel()
    quizGenerationTask = Task {
      do {
        let q = try await AIService(client: authService.getClient())
          .generateQuizQuestions(cards: cards, targetLanguage: wordSet.title)
        if Task.isCancelled { return }
        generatedQuestions = q
        isGeneratingQuiz = false
      } catch {
        if Task.isCancelled { return }
        quizGenerateError = error.localizedDescription
        isGeneratingQuiz = false
      }
    }
  }

  // MARK: - Card Deletion

  /// 刪除卡片：本地 modelContext 寫入 + Widget reload + 雲端同步刪除。
  func deleteCards(at offsets: IndexSet, in cards: [Card], modelContext: ModelContext, authService: AuthService) {
    let idsToDelete = offsets.map { cards[$0].id }
    for index in offsets {
      modelContext.delete(cards[index])
    }
    do {
      try modelContext.save()
      WidgetReloader.reloadAll()
      if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
        Task {
          for id in idsToDelete {
            await sync.deleteCard(id: id)
          }
        }
      }
    } catch {
      AppLog.wordset.info("❌ Failed to delete card: \(error.localizedDescription)")
      errorMessage = AppError.databaseError(error.localizedDescription).errorDescription
    }
  }

  // MARK: - Quiz Result

  /// 記錄選擇題測驗結果：寫入 StudyLog、回報每日任務、發放 EXP。
  func recordChoiceQuizResult(
    score: Int,
    total: Int,
    modelContext: ModelContext,
    questService: DailyQuestService,
    experienceStore: ExperienceStore
  ) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let log = StudyLog(date: today, cardsReviewed: score, totalCards: total, activityType: "multipleChoiceQuiz")
    modelContext.insert(log)
    try? modelContext.save()
    questService.recordWordSetCompleted(experienceStore: experienceStore)
    let accuracy = total > 0 ? Int(Double(score) / Double(total) * 100) : 0
    questService.recordWordSetQuizResult(
      accuracyPercent: accuracy,
      isPerfect: (total > 0 && score == total),
      quizType: .multipleChoice,
      experienceStore: experienceStore
    )
  }
}
