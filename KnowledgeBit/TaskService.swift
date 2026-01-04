// TaskService.swift
// 處理今日任務相關邏輯

import Foundation
import Combine

class TaskService: ObservableObject {
  private let userDefaults: UserDefaults
  
  // Published 屬性，UI 會自動更新
  @Published var reviewTaskDone: Bool = false
  @Published var quizTaskDone: Bool = false
  @Published var todayReviewCount: Int = 0
  
  init() {
    guard let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
      fatalError("無法取得 App Group UserDefaults")
    }
    self.userDefaults = sharedDefaults
    
    // 檢查並重置任務（如果日期改變）
    checkAndResetTasksIfNeeded()
    loadTaskStatus()
  }
  
  // MARK: - 檢查並重置任務
  // 如果日期改變，重置所有任務狀態
  private func checkAndResetTasksIfNeeded() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // 檢查上次完成任務的日期
    if let lastReviewDate = userDefaults.object(forKey: "task_review_done_date") as? Date,
       let lastQuizDate = userDefaults.object(forKey: "task_quiz_done_date") as? Date {
      
      let lastReviewDay = calendar.startOfDay(for: lastReviewDate)
      let lastQuizDay = calendar.startOfDay(for: lastQuizDate)
      
      // 如果上次完成日期不是今天，重置任務
      if !calendar.isDate(lastReviewDay, inSameDayAs: today) {
        userDefaults.removeObject(forKey: "task_review_done_date")
        userDefaults.removeObject(forKey: "today_review_count")
        print("🔄 [Task] 重置複習任務")
      }
      
      if !calendar.isDate(lastQuizDay, inSameDayAs: today) {
        userDefaults.removeObject(forKey: "task_quiz_done_date")
        print("🔄 [Task] 重置測驗任務")
      }
    }
  }
  
  // MARK: - 載入任務狀態
  private func loadTaskStatus() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // 檢查複習任務
    if let lastReviewDate = userDefaults.object(forKey: "task_review_done_date") as? Date {
      reviewTaskDone = calendar.isDate(lastReviewDate, inSameDayAs: today)
    } else {
      reviewTaskDone = false
    }
    
    // 檢查測驗任務
    if let lastQuizDate = userDefaults.object(forKey: "task_quiz_done_date") as? Date {
      quizTaskDone = calendar.isDate(lastQuizDate, inSameDayAs: today)
    } else {
      quizTaskDone = false
    }
    
    // 載入今日複習數量
    todayReviewCount = userDefaults.integer(forKey: "today_review_count")
  }
  
  // MARK: - 完成複習任務
  // 任務 A：完成 1 次複習 session（至少 10 張）→ +30 EXP
  func completeReviewTask(reviewCount: Int, experienceStore: ExperienceStore) -> Bool {
    guard reviewCount >= 10 else {
      print("⚠️ [Task] 複習任務未完成：需要至少 10 張，目前 \(reviewCount) 張")
      return false
    }
    
    // 檢查今天是否已完成
    if reviewTaskDone {
      print("ℹ️ [Task] 複習任務今天已完成")
      return false
    }
    
    // 標記為完成
    let today = Date()
    userDefaults.set(today, forKey: "task_review_done_date")
    reviewTaskDone = true
    
    // 給予 EXP
    experienceStore.addExp(delta: 30)
    
    print("✅ [Task] 完成複習任務！獲得 30 EXP")
    return true
  }
  
  // MARK: - 完成測驗任務
  // 任務 B：完成 1 次每日測驗 → +20 EXP
  func completeQuizTask(experienceStore: ExperienceStore) -> Bool {
    // 檢查今天是否已完成
    if quizTaskDone {
      print("ℹ️ [Task] 測驗任務今天已完成")
      return false
    }
    
    // 標記為完成
    let today = Date()
    userDefaults.set(today, forKey: "task_quiz_done_date")
    quizTaskDone = true
    
    // 給予 EXP
    experienceStore.addExp(delta: 20)
    
    print("✅ [Task] 完成測驗任務！獲得 20 EXP")
    return true
  }
  
  // MARK: - 增加今日複習數量
  func incrementReviewCount() {
    todayReviewCount += 1
    userDefaults.set(todayReviewCount, forKey: "today_review_count")
    print("📊 [Task] 今日複習數量: \(todayReviewCount)")
  }
}
