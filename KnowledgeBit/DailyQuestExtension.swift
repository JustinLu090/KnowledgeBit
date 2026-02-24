// DailyQuestExtension.swift
// Extension and helper methods for connecting daily quests to actual learning data

import Foundation

/*
 每日任務（七項）與對應 API：
 1. 學習時長 5 分鐘 20 Exp → questService.recordStudyMinutes(minutes, experienceStore:)
 2. 完成一本單字集複習 15 Exp → questService.recordWordSetCompleted(experienceStore:)
 3. 完成兩本單字集複習 25 Exp → 同上，完成第二本時再呼叫一次
 4. 單字集複習答對率超過 90% 15 Exp → recordWordSetQuizResult(..., quizType: .general 或 .multipleChoice)
 5. 單字集複習全對 20 Exp → 僅 quizType == .general 且全對時觸發
 6. 選擇題測驗全對 20 Exp → 僅 quizType == .multipleChoice 且全對時觸發
 7. 獲得 30 經驗值 10 Exp → questService.recordExpGainedToday(amount, experienceStore:)
 */

extension DailyQuestService {
  /// Convenience method to update quest progress by type（需傳入 experienceStore 以發放 EXP）
  enum QuestType {
    case studyMinutes(Int)
    case wordSetCompleted
    case wordSetQuizResult(accuracyPercent: Int, isPerfect: Bool, quizType: QuizType)
    case expGained(Int)
  }
  
  /// Update quest progress by type；完成時會自動發放對應 EXP
  func updateQuest(_ type: QuestType, experienceStore: ExperienceStore) {
    switch type {
    case .studyMinutes(let minutes):
      recordStudyMinutes(minutes, experienceStore: experienceStore)
    case .wordSetCompleted:
      recordWordSetCompleted(experienceStore: experienceStore)
    case .wordSetQuizResult(let accuracyPercent, let isPerfect, let quizType):
      recordWordSetQuizResult(accuracyPercent: accuracyPercent, isPerfect: isPerfect, quizType: quizType, experienceStore: experienceStore)
    case .expGained(let amount):
      recordExpGainedToday(amount, experienceStore: experienceStore)
    }
  }
}
