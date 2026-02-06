// DailyQuest.swift
// Daily quest model and data structure

import Foundation
import Combine

/// Daily quest model
struct DailyQuest: Identifiable {
  let id: UUID
  let title: String
  let targetValue: Int
  var currentProgress: Int
  let rewardExp: Int
  var isCompleted: Bool
  let iconName: String
  
  init(id: UUID = UUID(), title: String, targetValue: Int, currentProgress: Int = 0, rewardExp: Int, iconName: String) {
    self.id = id
    self.title = title
    self.targetValue = targetValue
    self.currentProgress = currentProgress
    self.rewardExp = rewardExp
    self.isCompleted = currentProgress >= targetValue
    self.iconName = iconName
  }
  
  /// Progress percentage (0.0 to 1.0)
  var progressPercentage: Double {
    guard targetValue > 0 else { return 0 }
    return min(Double(currentProgress) / Double(targetValue), 1.0)
  }
  
  /// Update progress and check completion
  mutating func updateProgress(_ newProgress: Int) {
    currentProgress = newProgress
    isCompleted = currentProgress >= targetValue
  }
}

/// Daily quest service to manage quests (persisted with UserDefaults, shared across app)
class DailyQuestService: ObservableObject {
  @Published var quests: [DailyQuest] = []
  
  private let userDefaults: UserDefaults
  private let questProgressKey = "daily_quest_progress"
  private let questDateKey = "daily_quest_date"
  private let todayCardsKey = "daily_quest_today_cards"
  private let todayExpKey = "daily_quest_today_exp"
  
  init() {
    guard let shared = UserDefaults(suiteName: AppGroup.identifier) else {
      fatalError("App Group UserDefaults not available")
    }
    self.userDefaults = shared
    loadOrResetQuests()
  }
  
  /// Check if we need to reset (new day) and load or initialize quests
  private func loadOrResetQuests() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    if let savedDate = userDefaults.object(forKey: questDateKey) as? Date,
       calendar.isDate(savedDate, inSameDayAs: today) {
      // Same day: load saved progress
      loadQuestsFromStorage()
    } else {
      // New day: reset and save date
      userDefaults.set(today, forKey: questDateKey)
      userDefaults.set(0, forKey: todayCardsKey)
      userDefaults.set(0, forKey: todayExpKey)
      loadQuests()
      saveQuestsToStorage()
    }
  }
  
  private func loadQuests() {
    let titles = ["完成三張卡片", "精準打擊", "學習長跑", "經驗獵人"]
    let targets = [3, 1, 3, 50]
    let rewards = [10, 20, 15, 30]
    let icons = ["book.fill", "target", "clock", "bolt.fill"]
    
    quests = (0..<4).map { i in
      DailyQuest(
        title: titles[i],
        targetValue: targets[i],
        currentProgress: 0,
        rewardExp: rewards[i],
        iconName: icons[i]
      )
    }
  }
  
  private func loadQuestsFromStorage() {
    let todayCards = userDefaults.integer(forKey: todayCardsKey)
    let todayExp = userDefaults.integer(forKey: todayExpKey)
    
    loadQuests()
    
    // Restore 完成三張卡片 and 經驗獵人 from today's totals
    if let idx = quests.firstIndex(where: { $0.title == "完成三張卡片" }) {
      quests[idx].updateProgress(min(todayCards, 3))
    }
    if let idx = quests.firstIndex(where: { $0.title == "經驗獵人" }) {
      quests[idx].updateProgress(min(todayExp, 50))
    }
    
    // Restore other quests (精準打擊, 學習長跑) from saved progress
    if let data = userDefaults.data(forKey: questProgressKey),
       let decoded = try? JSONDecoder().decode([QuestProgressSave].self, from: data),
       decoded.count == quests.count {
      for (i, saved) in decoded.enumerated() where i < quests.count {
        let title = quests[i].title
        if title == "精準打擊" || title == "學習長跑" {
          quests[i].currentProgress = saved.progress
          quests[i].isCompleted = saved.isCompleted
        }
      }
    }
  }
  
  private func saveQuestsToStorage() {
    let toSave = quests.map { QuestProgressSave(progress: $0.currentProgress, isCompleted: $0.isCompleted) }
    if let data = try? JSONEncoder().encode(toSave) {
      userDefaults.set(data, forKey: questProgressKey)
    }
    userDefaults.synchronize()
  }
  
  private struct QuestProgressSave: Codable {
    let progress: Int
    let isCompleted: Bool
  }
  
  /// Record cards completed today (quiz or review), update 完成三張卡片, award EXP if just completed
  func recordCardsCompletedToday(_ count: Int, experienceStore: ExperienceStore) {
    let current = userDefaults.integer(forKey: todayCardsKey)
    let newTotal = current + count
    userDefaults.set(newTotal, forKey: todayCardsKey)
    
    if let index = quests.firstIndex(where: { $0.title == "完成三張卡片" }) {
      let wasCompleted = quests[index].isCompleted
      quests[index].updateProgress(min(newTotal, 3))
      saveQuestsToStorage()
      
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        print("✅ [Quest] 完成三張卡片 - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
  }
  
  /// Record quiz with accuracy; if >= 90%, complete 精準打擊 and award EXP
  func recordQuizAccuracy(accuracyPercent: Int, experienceStore: ExperienceStore) {
    guard let index = quests.firstIndex(where: { $0.title == "精準打擊" }) else { return }
    let wasCompleted = quests[index].isCompleted
    let progress = accuracyPercent >= 90 ? 1 : 0
    quests[index].updateProgress(progress)
    saveQuestsToStorage()
    
    if !wasCompleted && quests[index].isCompleted {
      experienceStore.addExp(delta: quests[index].rewardExp)
      recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
      print("✅ [Quest] 精準打擊 - 獲得 \(quests[index].rewardExp) EXP")
    }
  }
  
  /// Record EXP gained today (e.g. from 今日任務・測驗), update 經驗獵人 progress only（不再發放經驗獵人 EXP）
  func recordExpGainedToday(_ amount: Int, experienceStore: ExperienceStore) {
    let current = userDefaults.integer(forKey: todayExpKey)
    let newTotal = current + amount
    userDefaults.set(newTotal, forKey: todayExpKey)
    
    if let index = quests.firstIndex(where: { $0.title == "經驗獵人" }) {
      quests[index].updateProgress(min(newTotal, 50))
      saveQuestsToStorage()
      // 經驗獵人不再發放 EXP，僅更新進度
    }
  }
  
  /// Update progress for a specific quest (generic). 僅「完成三張卡片」「精準打擊」會發放 EXP。
  func updateProgress(questId: UUID, progress: Int, experienceStore: ExperienceStore?) {
    if let index = quests.firstIndex(where: { $0.id == questId }) {
      let wasCompleted = quests[index].isCompleted
      quests[index].updateProgress(progress)
      saveQuestsToStorage()
      
      let title = quests[index].title
      let shouldAwardExp = (title == "完成三張卡片" || title == "精準打擊")
      if !wasCompleted && quests[index].isCompleted, let store = experienceStore, shouldAwardExp {
        store.addExp(delta: quests[index].rewardExp)
        print("✅ [Quest] \(title) - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
  }
  
  func updateProgress(title: String, progress: Int, experienceStore: ExperienceStore? = nil) {
    if let quest = quests.first(where: { $0.title == title }) {
      updateProgress(questId: quest.id, progress: progress, experienceStore: experienceStore)
    }
  }
  
  /// Today's total cards completed (for display)
  var todayCardsCompleted: Int {
    userDefaults.integer(forKey: todayCardsKey)
  }
  
  /// Today's total EXP gained (for 經驗獵人)
  var todayExpGained: Int {
    userDefaults.integer(forKey: todayExpKey)
  }
  
  var completedCount: Int {
    quests.filter { $0.isCompleted }.count
  }
  
  var totalCount: Int {
    quests.count
  }
  
  func resetQuests() {
    userDefaults.removeObject(forKey: questProgressKey)
    userDefaults.set(0, forKey: todayCardsKey)
    userDefaults.set(0, forKey: todayExpKey)
    loadQuests()
    saveQuestsToStorage()
  }
}
