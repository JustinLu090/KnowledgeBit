// DailyQuestExtension.swift
// Extension and helper methods for connecting daily quests to actual learning data

import Foundation

/// 每日任務更新所呼叫的服務方法（`DailyQuestService` 實作；測試可用 mock）
protocol DailyQuestQuestRecording: AnyObject {
  func recordStudyMinutes(_ minutes: Int, experienceStore: ExperienceStore)
  func recordWordSetCompleted(experienceStore: ExperienceStore)
  func recordWordSetQuizResult(accuracyPercent: Int, isPerfect: Bool, quizType: QuizType, experienceStore: ExperienceStore)
  func recordExpGainedToday(_ amount: Int, experienceStore: ExperienceStore)
}

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

extension DailyQuestService: DailyQuestQuestRecording {}

extension DailyQuestService {
  /// Convenience method to update quest progress by type（需傳入 experienceStore 以發放 EXP）
  enum QuestType {
    case studyMinutes(Int)
    case wordSetCompleted
    case wordSetQuizResult(accuracyPercent: Int, isPerfect: Bool, quizType: QuizType)
    case expGained(Int)

    /// 將任務類型對應到服務方法（與 `updateQuest` 行為一致，便於單元測試 mock）
    func apply(to recorder: DailyQuestQuestRecording, experienceStore: ExperienceStore) {
      switch self {
      case .studyMinutes(let minutes):
        recorder.recordStudyMinutes(minutes, experienceStore: experienceStore)
      case .wordSetCompleted:
        recorder.recordWordSetCompleted(experienceStore: experienceStore)
      case .wordSetQuizResult(let accuracyPercent, let isPerfect, let quizType):
        recorder.recordWordSetQuizResult(
          accuracyPercent: accuracyPercent,
          isPerfect: isPerfect,
          quizType: quizType,
          experienceStore: experienceStore
        )
      case .expGained(let amount):
        recorder.recordExpGainedToday(amount, experienceStore: experienceStore)
      }
    }
  }

  /// Update quest progress by type；完成時會自動發放對應 EXP
  func updateQuest(_ type: QuestType, experienceStore: ExperienceStore) {
    type.apply(to: self, experienceStore: experienceStore)
  }
}
