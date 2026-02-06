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
  private let todayStudyMinutesKey = "daily_quest_today_study_minutes"
  private let todayWordSetsCompletedKey = "daily_quest_today_word_sets"
  
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
      userDefaults.set(0, forKey: todayStudyMinutesKey)
      userDefaults.set(0, forKey: todayWordSetsCompletedKey)
      loadQuests()
      saveQuestsToStorage()
    }
  }
  
  private func loadQuests() {
    // 1. 學習時長 5 分鐘 20 Exp  2. 完成一本單字集複習 15 Exp  3. 完成兩本單字集複習 25 Exp
    // 4. 單字集複習答對率超過 90% 15 Exp  5. 單字集複習全對 20 Exp  6. 獲得 30 經驗值 10 Exp
    let titles = [
      "學習時長 5 分鐘",
      "完成一本單字集複習",
      "完成兩本單字集複習",
      "單字集複習答對率超過 90%",
      "單字集複習全對",
      "獲得 30 經驗值"
    ]
    let targets = [5, 1, 2, 1, 1, 30]
    let rewards = [20, 15, 25, 15, 20, 10]
    let icons = ["clock.fill", "book.fill", "books.vertical.fill", "percent", "checkmark.circle.fill", "bolt.fill"]
    
    quests = (0..<6).map { i in
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
    let todayExp = userDefaults.integer(forKey: todayExpKey)
    let todayMinutes = userDefaults.integer(forKey: todayStudyMinutesKey)
    let todayWordSets = userDefaults.integer(forKey: todayWordSetsCompletedKey)
    
    loadQuests()
    
    // Restore progress from today's totals
    if let idx = quests.firstIndex(where: { $0.title == "學習時長 5 分鐘" }) {
      quests[idx].updateProgress(min(todayMinutes, 5))
    }
    if let idx = quests.firstIndex(where: { $0.title == "完成一本單字集複習" }) {
      quests[idx].updateProgress(min(todayWordSets, 1))
    }
    if let idx = quests.firstIndex(where: { $0.title == "完成兩本單字集複習" }) {
      quests[idx].updateProgress(min(todayWordSets, 2))
    }
    if let idx = quests.firstIndex(where: { $0.title == "獲得 30 經驗值" }) {
      quests[idx].updateProgress(min(todayExp, 30))
    }
    
    // Restore 單字集複習答對率超過 90%、單字集複習全對 from saved progress
    if let data = userDefaults.data(forKey: questProgressKey),
       let decoded = try? JSONDecoder().decode([QuestProgressSave].self, from: data),
       decoded.count == quests.count {
      for (i, saved) in decoded.enumerated() where i < quests.count {
        let title = quests[i].title
        if title == "單字集複習答對率超過 90%" || title == "單字集複習全對" {
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
  
  /// 記錄今日獲得的經驗值；更新「獲得 30 經驗值」任務，達成時發放 10 EXP
  func recordExpGainedToday(_ amount: Int, experienceStore: ExperienceStore) {
    let current = userDefaults.integer(forKey: todayExpKey)
    let newTotal = current + amount
    userDefaults.set(newTotal, forKey: todayExpKey)
    
    if let index = quests.firstIndex(where: { $0.title == "獲得 30 經驗值" }) {
      let wasCompleted = quests[index].isCompleted
      quests[index].updateProgress(min(newTotal, 30))
      saveQuestsToStorage()
      
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        print("✅ [Quest] 獲得 30 經驗值 - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
  }
  
  /// 記錄今日學習時長（分鐘）；更新「學習時長 5 分鐘」，達成時發放 20 EXP
  func recordStudyMinutes(_ minutes: Int, experienceStore: ExperienceStore) {
    let current = userDefaults.integer(forKey: todayStudyMinutesKey)
    let newTotal = current + minutes
    userDefaults.set(newTotal, forKey: todayStudyMinutesKey)
    
    if let index = quests.firstIndex(where: { $0.title == "學習時長 5 分鐘" }) {
      let wasCompleted = quests[index].isCompleted
      quests[index].updateProgress(min(newTotal, 5))
      saveQuestsToStorage()
      
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        print("✅ [Quest] 學習時長 5 分鐘 - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
  }
  
  /// 記錄完成一本單字集複習；更新「完成一本」「完成兩本」任務，達成時各發放 15 / 25 EXP
  func recordWordSetCompleted(experienceStore: ExperienceStore) {
    let current = userDefaults.integer(forKey: todayWordSetsCompletedKey)
    let newTotal = current + 1
    userDefaults.set(newTotal, forKey: todayWordSetsCompletedKey)
    
    for title in ["完成一本單字集複習", "完成兩本單字集複習"] {
      guard let index = quests.firstIndex(where: { $0.title == title }) else { continue }
      let wasCompleted = quests[index].isCompleted
      let target = quests[index].targetValue
      quests[index].updateProgress(min(newTotal, target))
      saveQuestsToStorage()
      
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        print("✅ [Quest] \(title) - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
  }
  
  /// 記錄單字集複習結果：答對率與是否全對；更新「答對率超過 90%」「全對」任務，達成時各發放 15 / 20 EXP
  func recordWordSetQuizResult(accuracyPercent: Int, isPerfect: Bool, experienceStore: ExperienceStore) {
    if let index = quests.firstIndex(where: { $0.title == "單字集複習答對率超過 90%" }) {
      let wasCompleted = quests[index].isCompleted
      quests[index].updateProgress(accuracyPercent >= 90 ? 1 : 0)
      saveQuestsToStorage()
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        print("✅ [Quest] 單字集複習答對率超過 90% - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
    if let index = quests.firstIndex(where: { $0.title == "單字集複習全對" }) {
      let wasCompleted = quests[index].isCompleted
      quests[index].updateProgress(isPerfect ? 1 : 0)
      saveQuestsToStorage()
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        print("✅ [Quest] 單字集複習全對 - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
  }
  
  /// Update progress for a specific quest (generic). 六個每日任務完成時皆會發放對應 EXP。
  func updateProgress(questId: UUID, progress: Int, experienceStore: ExperienceStore?) {
    if let index = quests.firstIndex(where: { $0.id == questId }) {
      let wasCompleted = quests[index].isCompleted
      quests[index].updateProgress(progress)
      saveQuestsToStorage()
      
      if !wasCompleted && quests[index].isCompleted, let store = experienceStore {
        store.addExp(delta: quests[index].rewardExp)
        print("✅ [Quest] \(quests[index].title) - 獲得 \(quests[index].rewardExp) EXP")
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
  
  /// Today's total EXP gained（供「獲得 30 經驗值」等任務使用）
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
    userDefaults.set(0, forKey: todayStudyMinutesKey)
    userDefaults.set(0, forKey: todayWordSetsCompletedKey)
    loadQuests()
    saveQuestsToStorage()
  }
  
  /// 今日累積學習分鐘數（供 UI 顯示用）
  var todayStudyMinutes: Int {
    userDefaults.integer(forKey: todayStudyMinutesKey)
  }
  
  /// 今日完成複習的單字集數量（供 UI 顯示用）
  var todayWordSetsCompleted: Int {
    userDefaults.integer(forKey: todayWordSetsCompletedKey)
  }
}
