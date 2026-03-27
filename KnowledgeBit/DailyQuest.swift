// DailyQuest.swift
// Daily quest model and data structure

import Foundation
import Combine

/// 測驗類型：用於區分一般單字測驗與選擇題測驗，以更新對應的每日任務
enum QuizType {
  /// 一般單字測驗（拼字、填空、翻卡等）
  case general
  /// 選擇題測驗（挖空 + 四選一）
  case multipleChoice
}

/// 測驗結果是否符合每日任務條件（與 `recordWordSetQuizResult` 一致，便於單元測試）
enum DailyQuestQuizRules {
  static func satisfiesAccuracyOver90(accuracyPercent: Int) -> Bool {
    accuracyPercent >= 90
  }

  static func satisfiesWordSetPerfect(quizType: QuizType, isPerfect: Bool) -> Bool {
    quizType == .general && isPerfect
  }

  static func satisfiesMultipleChoicePerfect(quizType: QuizType, isPerfect: Bool) -> Bool {
    quizType == .multipleChoice && isPerfect
  }
}

private struct DailyQuestSeededRNG: RandomNumberGenerator {
  var state: UInt64

  init(seed: Int) {
    state = UInt64(seed)
  }

  mutating func next() -> UInt64 {
    state = state &* 1103515245 &+ 12345
    return state
  }
}

/// 七項每日任務池的靜態定義（與 `DailyQuestService` 載入邏輯一致，供測試與文件對照）
struct DailyQuestDefinition: Equatable {
  let title: String
  let targetValue: Int
  let rewardExp: Int
  let iconName: String
}

enum DailyQuestCatalog {
  static let definitions: [DailyQuestDefinition] = [
    DailyQuestDefinition(title: "學習時長 5 分鐘", targetValue: 5, rewardExp: 20, iconName: "clock.fill"),
    DailyQuestDefinition(title: "完成一本單字集複習", targetValue: 1, rewardExp: 15, iconName: "book.fill"),
    DailyQuestDefinition(title: "完成兩本單字集複習", targetValue: 2, rewardExp: 25, iconName: "books.vertical.fill"),
    DailyQuestDefinition(title: "單字集複習答對率超過 90%", targetValue: 1, rewardExp: 15, iconName: "percent"),
    DailyQuestDefinition(title: "單字集複習全對", targetValue: 1, rewardExp: 20, iconName: "checkmark.circle.fill"),
    DailyQuestDefinition(title: "選擇題測驗全對", targetValue: 1, rewardExp: 20, iconName: "list.bullet.circle.fill"),
    DailyQuestDefinition(title: "獲得 30 經驗值", targetValue: 30, rewardExp: 10, iconName: "bolt.fill")
  ]

  static var poolCount: Int { definitions.count }
}

/// 依「日」種子從 0...6 選出 3 個不重複索引（與 `DailyQuestService.selectRandomQuests` 一致）
enum DailyQuestRandomSelection {
  static func indices(for date: Date) -> [Int] {
    let seed = Int(date.timeIntervalSince1970 / 86400)
    var generator = DailyQuestSeededRNG(seed: seed)
    var indices = Array(0..<DailyQuestCatalog.poolCount)
    indices.shuffle(using: &generator)
    return Array(indices.prefix(3)).sorted()
  }
}

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
  
  /// Update progress and check completion.
  /// 目標為 1 的任務（如全對類）僅接受 0 或 1，避免誤寫成 rewardExp 等造成 20/1 顯示異常。
  mutating func updateProgress(_ newProgress: Int) {
    if targetValue == 1 {
      currentProgress = newProgress >= 1 ? 1 : 0
    } else {
      currentProgress = newProgress
    }
    isCompleted = currentProgress >= targetValue
  }
  
  /// 供每日任務清單顯示的標題（可區分單字複習全對與選擇題全對）
  var displayTitle: String {
    switch title {
    case "單字集複習全對": return "單字複習：完美達成"
    case "選擇題測驗全對": return "選擇題挑戰：全對"
    default: return title
    }
  }
}

/// Daily quest service to manage quests (persisted with UserDefaults, shared across app)
class DailyQuestService: ObservableObject {
  @Published var quests: [DailyQuest] = []
  
  private let userDefaults: UserDefaults
  private let questProgressKey = "daily_quest_progress"
  private let questDateKey = "daily_quest_date"
  private let selectedQuestIndicesKey = "daily_quest_selected_indices" // 儲存今天選中的任務索引
  private let todayCardsKey = "daily_quest_today_cards"
  private let todayExpKey = "daily_quest_today_exp"
  private let todayStudyMinutesKey = "daily_quest_today_study_minutes"
  private let todayWordSetsCompletedKey = "daily_quest_today_word_sets"
  
  init() {
    if let shared = UserDefaults(suiteName: AppGroup.identifier) {
      self.userDefaults = shared
    } else {
      print("⚠️ [DailyQuest] App Group UserDefaults not available, falling back to standard")
      self.userDefaults = .standard
    }
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
      // New day: reset and save date, randomly select 3 quests
      userDefaults.set(today, forKey: questDateKey)
      userDefaults.set(0, forKey: todayCardsKey)
      userDefaults.set(0, forKey: todayExpKey)
      userDefaults.set(0, forKey: todayStudyMinutesKey)
      userDefaults.set(0, forKey: todayWordSetsCompletedKey)
      
      // 隨機選三個任務（基於日期作為種子，確保同一天選出的任務相同）
      let selectedIndices = selectRandomQuests(for: today)
      userDefaults.set(selectedIndices, forKey: selectedQuestIndicesKey)
      
      loadQuests(selectedIndices: selectedIndices)
      saveQuestsToStorage()
    }
  }
  
  /// 基於日期隨機選出三個任務（同一天會選出相同的任務）
  private func selectRandomQuests(for date: Date) -> [Int] {
    DailyQuestRandomSelection.indices(for: date)
  }

  private func loadQuests(selectedIndices: [Int]? = nil) {
    // 如果沒有提供選中的索引，從 UserDefaults 讀取
    let indices: [Int]
    if let provided = selectedIndices {
      indices = provided
    } else if let saved = userDefaults.array(forKey: selectedQuestIndicesKey) as? [Int] {
      indices = saved
    } else {
      // 如果都沒有，使用今天的日期重新選
      let today = Calendar.current.startOfDay(for: Date())
      indices = selectRandomQuests(for: today)
      userDefaults.set(indices, forKey: selectedQuestIndicesKey)
    }
    
    // 只加載選中的三個任務
    quests = indices.map { i in
      let d = DailyQuestCatalog.definitions[i]
      return DailyQuest(
        title: d.title,
        targetValue: d.targetValue,
        currentProgress: 0,
        rewardExp: d.rewardExp,
        iconName: d.iconName
      )
    }
  }
  
  private func loadQuestsFromStorage() {
    let todayExp = userDefaults.integer(forKey: todayExpKey)
    let todayMinutes = userDefaults.integer(forKey: todayStudyMinutesKey)
    let todayWordSets = userDefaults.integer(forKey: todayWordSetsCompletedKey)
    
    loadQuests()
    
    // Restore progress from today's totals（只恢復今天選中的任務）
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
    
    // Restore 單字集複習答對率超過 90%、單字集複習全對、選擇題測驗全對 from saved progress（目標為 1 的任務進度上限為 1，避免 20/1 等異常）
    if let data = userDefaults.data(forKey: questProgressKey),
       let decoded = try? JSONDecoder().decode([QuestProgressSave].self, from: data),
       decoded.count == quests.count {
      for (i, saved) in decoded.enumerated() where i < quests.count {
        let title = quests[i].title
        if title == "單字集複習答對率超過 90%" || title == "單字集複習全對" || title == "選擇題測驗全對" {
          let cap = quests[i].targetValue == 1 ? min(saved.progress, 1) : saved.progress
          quests[i].currentProgress = cap
          quests[i].isCompleted = saved.isCompleted || cap >= quests[i].targetValue
        }
      }
    }
    notifyQuestsDidChange()
  }
  
  private func saveQuestsToStorage() {
    let toSave = quests.map { QuestProgressSave(progress: $0.currentProgress, isCompleted: $0.isCompleted) }
    if let data = try? JSONEncoder().encode(toSave) {
      userDefaults.set(data, forKey: questProgressKey)
    }
    userDefaults.synchronize()
  }

  /// 每次任務首次完成時呼叫，觸發成就系統
  private func onQuestFirstCompleted() {
    AchievementService.shared.recordDailyQuestCompleted()
  }

  /// 通知 UI 更新（mutating 陣列內 struct 不會觸發 @Published）
  private func notifyQuestsDidChange() {
    if Thread.isMainThread {
      objectWillChange.send()
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.objectWillChange.send()
      }
    }
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
      notifyQuestsDidChange()
      
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        onQuestFirstCompleted()
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
      notifyQuestsDidChange()
      
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        onQuestFirstCompleted()
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
      notifyQuestsDidChange()
      
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        onQuestFirstCompleted()
        print("✅ [Quest] \(title) - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
  }
  
  /// 記錄單字集／選擇題測驗結果：依測驗類型更新對應任務，達成時發放 EXP。
  /// - Parameter quizType: 測驗類型（.general 僅更新「單字集複習全對」；.multipleChoice 僅更新「選擇題測驗全對」）
  /// 任務具持久性：一旦當日曾達成即保持已完成，不會因後續測驗未達標而被重置。
  func recordWordSetQuizResult(accuracyPercent: Int, isPerfect: Bool, quizType: QuizType, experienceStore: ExperienceStore) {
    // 答對率超過 90%：兩種測驗皆可觸發
    if let index = quests.firstIndex(where: { $0.title == "單字集複習答對率超過 90%" }) {
      let wasCompleted = quests[index].isCompleted
      if DailyQuestQuizRules.satisfiesAccuracyOver90(accuracyPercent: accuracyPercent) {
        quests[index].updateProgress(1)
      }
      saveQuestsToStorage()
      notifyQuestsDidChange()
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        onQuestFirstCompleted()
        print("✅ [Quest] 單字集複習答對率超過 90% - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
    // 單字集複習全對：僅一般單字測驗 (.general) 且全對時觸發
    if let index = quests.firstIndex(where: { $0.title == "單字集複習全對" }) {
      let wasCompleted = quests[index].isCompleted
      if DailyQuestQuizRules.satisfiesWordSetPerfect(quizType: quizType, isPerfect: isPerfect) {
        quests[index].updateProgress(1)
      }
      saveQuestsToStorage()
      notifyQuestsDidChange()
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        onQuestFirstCompleted()
        print("✅ [Quest] 單字集複習全對 - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
    // 選擇題測驗全對：僅選擇題測驗 (.multipleChoice) 且全對時觸發
    if let index = quests.firstIndex(where: { $0.title == "選擇題測驗全對" }) {
      let wasCompleted = quests[index].isCompleted
      if DailyQuestQuizRules.satisfiesMultipleChoicePerfect(quizType: quizType, isPerfect: isPerfect) {
        quests[index].updateProgress(1)
      }
      saveQuestsToStorage()
      notifyQuestsDidChange()
      if !wasCompleted && quests[index].isCompleted {
        experienceStore.addExp(delta: quests[index].rewardExp)
        recordExpGainedToday(quests[index].rewardExp, experienceStore: experienceStore)
        onQuestFirstCompleted()
        print("✅ [Quest] 選擇題測驗全對 - 獲得 \(quests[index].rewardExp) EXP")
      }
    }
  }
  
  /// Update progress for a specific quest (generic). 七個每日任務完成時皆會發放對應 EXP。
  func updateProgress(questId: UUID, progress: Int, experienceStore: ExperienceStore?) {
    if let index = quests.firstIndex(where: { $0.id == questId }) {
      let wasCompleted = quests[index].isCompleted
      quests[index].updateProgress(progress)
      saveQuestsToStorage()
      notifyQuestsDidChange()
      
      if !wasCompleted && quests[index].isCompleted, let store = experienceStore {
        store.addExp(delta: quests[index].rewardExp)
        onQuestFirstCompleted()
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
    
    // 重新隨機選三個任務
    let today = Calendar.current.startOfDay(for: Date())
    let selectedIndices = selectRandomQuests(for: today)
    userDefaults.set(selectedIndices, forKey: selectedQuestIndicesKey)
    
    loadQuests(selectedIndices: selectedIndices)
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
  
  /// 從 UserDefaults 重新載入任務進度並通知 UI（首頁顯示時呼叫可確保與持久化同步）
  func refreshFromStorage() {
    loadQuestsFromStorage()
    notifyQuestsDidChange()
  }
  
  /// 若已過午夜（新的一天），重新載入並重置任務；回傳 true 表示已重置
  func refreshIfNewDay() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    if let savedDate = userDefaults.object(forKey: questDateKey) as? Date,
       calendar.isDate(savedDate, inSameDayAs: today) {
      // 同一天，僅確保從儲存恢復（例如從背景回來）並通知 UI
      loadQuestsFromStorage()
      notifyQuestsDidChange()
      return
    }
    // 新的一天：重置並重選任務
    userDefaults.set(today, forKey: questDateKey)
    userDefaults.set(0, forKey: todayCardsKey)
    userDefaults.set(0, forKey: todayExpKey)
    userDefaults.set(0, forKey: todayStudyMinutesKey)
    userDefaults.set(0, forKey: todayWordSetsCompletedKey)
    let selectedIndices = selectRandomQuests(for: today)
    userDefaults.set(selectedIndices, forKey: selectedQuestIndicesKey)
    loadQuests(selectedIndices: selectedIndices)
    saveQuestsToStorage()
    notifyQuestsDidChange()
  }
}
