// ExperienceStore.swift
// 統一管理使用者經驗值與等級的 ObservableObject
// 使用 App Group UserDefaults 儲存，確保主 App 與 Widget 共用資料

import Foundation
import SwiftUI
import Combine

class ExperienceStore: ObservableObject {
  // App Group UserDefaults
  private let userDefaults: UserDefaults
  
  // Published 屬性，UI 會自動更新
  @Published var level: Int {
    didSet {
      userDefaults.set(level, forKey: "userLevel")
      print("📊 [EXP] Level 更新: \(level)")
    }
  }
  
  @Published var exp: Int {
    didSet {
      userDefaults.set(exp, forKey: "userExp")
      print("📊 [EXP] EXP 更新: \(exp)")
    }
  }
  
  @Published var expToNext: Int {
    didSet {
      userDefaults.set(expToNext, forKey: "expToNext")
      print("📊 [EXP] expToNext 更新: \(expToNext)")
    }
  }
  
  // 計算升級所需 EXP 的函數（可自訂曲線）
  // 使用 static 方法，避免在初始化時需要使用 self
  private static func calculateExpToNext(for level: Int) -> Int {
    // 基礎值 100，每級增加 20%（可調整）
    let baseExp = 100
    let multiplier = pow(1.2, Double(level - 1))
    let calculated = Int(Double(baseExp) * multiplier)
    // 確保至少為 100，避免過小
    return max(calculated, 100)
  }
  
  // 初始化：從 App Group UserDefaults 讀取或使用預設值
  init() {
    guard let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
      fatalError("無法取得 App Group UserDefaults")
    }
    
    self.userDefaults = sharedDefaults
    
    // 讀取儲存的值，若無則使用預設值
    let savedLevel = max(userDefaults.integer(forKey: "userLevel"), 1) // 至少為 1
    let savedExp = max(userDefaults.integer(forKey: "userExp"), 0) // 至少為 0
    let savedExpToNext = userDefaults.integer(forKey: "expToNext")
    
    // 初始化 stored properties
    self.level = savedLevel
    self.exp = savedExp
    
    // 如果 expToNext 為 0 或未設定，根據當前等級計算
    if savedExpToNext > 0 {
      self.expToNext = savedExpToNext
    } else {
      // 使用靜態方法計算，避免在初始化前使用 self
      let calculatedExpToNext = ExperienceStore.calculateExpToNext(for: savedLevel)
      self.expToNext = calculatedExpToNext
      userDefaults.set(calculatedExpToNext, forKey: "expToNext")
    }
    
    print("📊 [EXP] 初始化完成 - Level: \(level), EXP: \(exp)/\(expToNext)")
  }
  
  // 增加經驗值
  // - delta: 要增加的 EXP 數量
  func addExp(delta: Int) {
    guard delta > 0 else {
      print("⚠️ [EXP] addExp 收到無效的 delta: \(delta)")
      return
    }
    
    let oldLevel = level
    let oldExp = exp
    
    // 增加 EXP
    exp += delta
    
    // 檢查是否需要升級
    while exp >= expToNext {
      // 升級
      level += 1
      exp -= expToNext
      
      // 計算下一級所需 EXP
      expToNext = ExperienceStore.calculateExpToNext(for: level)
      
      print("🎉 [EXP] 升級！新等級: \(level), 剩餘 EXP: \(exp), 下一級需要: \(expToNext)")
    }
    
    // Debug 輸出
    if oldLevel != level {
      print("📈 [EXP] 升級！Level \(oldLevel) → \(level), EXP: \(oldExp) → \(exp)/\(expToNext)")
    } else {
      print("📈 [EXP] 獲得 \(delta) EXP, 當前: \(exp)/\(expToNext) (Level \(level))")
    }
  }
  
  // 計算 EXP 百分比（0.0 ~ 1.0）
  var expPercentage: Double {
    guard expToNext > 0 else { return 0.0 }
    return min(Double(exp) / Double(expToNext), 1.0)
  }
}
