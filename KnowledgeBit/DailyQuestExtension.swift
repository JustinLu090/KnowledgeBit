// DailyQuestExtension.swift
// Extension and helper methods for connecting daily quests to actual learning data

import Foundation

/*
 Usage Examples:
 
 // 1. Update "完成三張卡片" quest when user reviews cards
 func onCardReviewed() {
   let questService = DailyQuestService()
   let currentProgress = getReviewedCardCount() // Your function to get count
   questService.updateProgress(title: "完成三張卡片", progress: currentProgress)
   
   if questService.quests.first(where: { $0.title == "完成三張卡片" })?.isCompleted == true {
     experienceStore.addExp(delta: 10)
   }
 }
 
 // 2. Update "精準打擊" quest when quiz is completed with high accuracy
 func onQuizCompleted(accuracy: Double) {
   let questService = DailyQuestService()
   if accuracy >= 0.9 {
     questService.updateProgress(title: "精準打擊", progress: 1)
     experienceStore.addExp(delta: 20)
   }
 }
 
 // 3. Update "學習長跑" quest based on study time
 func onStudyTimeUpdated(minutes: Int) {
   let questService = DailyQuestService()
   questService.updateProgress(title: "學習長跑", progress: minutes)
   
   if let quest = questService.quests.first(where: { $0.title == "學習長跑" }),
      quest.isCompleted {
     experienceStore.addExp(delta: 15)
   }
 }
 
 // 4. Update "經驗獵人" quest when EXP is gained
 func onExpGained(amount: Int) {
   let questService = DailyQuestService()
   let currentTotalExp = experienceStore.exp
   questService.updateProgress(title: "經驗獵人", progress: currentTotalExp)
   
   if let quest = questService.quests.first(where: { $0.title == "經驗獵人" }),
      quest.isCompleted {
     experienceStore.addExp(delta: 30)
   }
 }
 */

extension DailyQuestService {
  /// Convenience method to update quest progress by type
  enum QuestType {
    case completeCards(count: Int)
    case accurateStrike(achieved: Bool)
    case studyMarathon(minutes: Int)
    case expHunter(totalExp: Int)
  }
  
  /// Update quest progress by type
  func updateQuest(_ type: QuestType) {
    switch type {
    case .completeCards(let count):
      updateProgress(title: "完成三張卡片", progress: count)
    case .accurateStrike(let achieved):
      updateProgress(title: "精準打擊", progress: achieved ? 1 : 0)
    case .studyMarathon(let minutes):
      updateProgress(title: "學習長跑", progress: minutes)
    case .expHunter(let totalExp):
      updateProgress(title: "經驗獵人", progress: totalExp)
    }
  }
}
