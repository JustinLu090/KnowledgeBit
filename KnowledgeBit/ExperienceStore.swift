// ExperienceStore.swift
// 統一管理使用者經驗值與等級的 ObservableObject
// 使用 App Group UserDefaults 儲存，確保主 App 與 Widget 共用資料
//
// 經驗值僅由以下三種方式獲得（皆透過 addExp 累積，滿額即晉級）：
// 1. 今日任務・測驗：完成一次每日測驗 → +20 EXP
// 2. 每日任務・完成三張卡片：今日完成 3 張 → +10 EXP
// 3. 每日任務・精準打擊：單次測驗正確率 ≥90% → +20 EXP

import Foundation
import SwiftUI
import Combine
import Supabase
import WidgetKit

class ExperienceStore: ObservableObject {
  // App Group UserDefaults
  private let userDefaults: UserDefaults
  
  // AuthService 引用（用於雲端同步）
  // 使用 weak 引用避免循環引用
  weak var authService: AuthService?
  
  // Published 屬性，UI 會自動更新
  // 注意：@Published 的 didSet 會在屬性變更時立即執行，通常已在主線程
  // 優化：不在 didSet 中觸發 Widget 刷新，改為在 addExp 完成後統一刷新，避免重複呼叫
  @Published var level: Int {
    didSet {
      // UserDefaults 操作（@Published 通常已在主線程，但為安全起見確保在主線程）
      if Thread.isMainThread {
        userDefaults.set(level, forKey: AppGroup.Keys.level)
        userDefaults.synchronize()
        #if DEBUG
        print("📊 [EXP] Level 更新: \(level)")
        #endif
      } else {
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.userDefaults.set(self.level, forKey: AppGroup.Keys.level)
          self.userDefaults.synchronize()
          #if DEBUG
          print("📊 [EXP] Level 更新: \(self.level)")
          #endif
        }
      }
    }
  }

  @Published var exp: Int {
    didSet {
      if Thread.isMainThread {
        userDefaults.set(exp, forKey: AppGroup.Keys.exp)
        userDefaults.synchronize()
        #if DEBUG
        print("📊 [EXP] EXP 更新: \(exp)")
        #endif
      } else {
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.userDefaults.set(self.exp, forKey: AppGroup.Keys.exp)
          self.userDefaults.synchronize()
          #if DEBUG
          print("📊 [EXP] EXP 更新: \(self.exp)")
          #endif
        }
      }
    }
  }

  @Published var expToNext: Int {
    didSet {
      if Thread.isMainThread {
        userDefaults.set(expToNext, forKey: AppGroup.Keys.expToNext)
        userDefaults.synchronize()
        #if DEBUG
        print("📊 [EXP] expToNext 更新: \(expToNext)")
        #endif
      } else {
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.userDefaults.set(self.expToNext, forKey: AppGroup.Keys.expToNext)
          self.userDefaults.synchronize()
          #if DEBUG
          print("📊 [EXP] expToNext 更新: \(self.expToNext)")
          #endif
        }
      }
    }
  }
  
  /// 本週累積 EXP（週一重置），用於好友排行榜
  private(set) var weeklyExp: Int = 0

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
    if let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) {
      self.userDefaults = sharedDefaults
    } else {
      print("⚠️ [EXP] 無法取得 App Group UserDefaults，回退到標準 UserDefaults")
      self.userDefaults = .standard
    }
    
    // 讀取儲存的值，若無則使用預設值
    let savedLevel = max(userDefaults.integer(forKey: AppGroup.Keys.level), 1) // 至少為 1
    let savedExp = max(userDefaults.integer(forKey: AppGroup.Keys.exp), 0) // 至少為 0
    let savedExpToNext = userDefaults.integer(forKey: AppGroup.Keys.expToNext)

    // 週 EXP：若跨週則重置
    let calendar = Calendar.current
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    if let resetDate = userDefaults.object(forKey: AppGroup.Keys.weeklyExpResetDate) as? Date,
       calendar.isDate(resetDate, equalTo: weekStart, toGranularity: .weekOfYear) {
      self.weeklyExp = max(userDefaults.integer(forKey: AppGroup.Keys.weeklyExp), 0)
    } else {
      self.weeklyExp = 0
      userDefaults.set(0, forKey: AppGroup.Keys.weeklyExp)
      userDefaults.set(weekStart, forKey: AppGroup.Keys.weeklyExpResetDate)
    }

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
      userDefaults.set(calculatedExpToNext, forKey: AppGroup.Keys.expToNext)
    }
    
    #if DEBUG
    print("📊 [EXP] 初始化完成 - Level: \(level), EXP: \(exp)/\(expToNext)")
    #endif
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
    weeklyExp += delta
    userDefaults.set(weeklyExp, forKey: AppGroup.Keys.weeklyExp)
    
    // 檢查是否需要升級
    while exp >= expToNext {
      // 升級
      level += 1
      exp -= expToNext
      
      // 計算下一級所需 EXP
      expToNext = ExperienceStore.calculateExpToNext(for: level)
      
      #if DEBUG
      print("🎉 [EXP] 升級！新等級: \(level), 剩餘 EXP: \(exp), 下一級需要: \(expToNext)")
      #endif
    }

    #if DEBUG
    if oldLevel != level {
      print("📈 [EXP] 升級！Level \(oldLevel) → \(level), EXP: \(oldExp) → \(exp)/\(expToNext)")
    } else {
      print("📈 [EXP] 獲得 \(delta) EXP, 當前: \(exp)/\(expToNext) (Level \(level))")
    }
    #endif
    
    // 統一觸發 Widget 刷新（只在 addExp 完成後刷新一次，避免重複）
    // 確保在主線程執行
    if Thread.isMainThread {
      WidgetReloader.reloadAll()
    } else {
      DispatchQueue.main.async {
        WidgetReloader.reloadAll()
      }
    }
    
    // 自動同步到雲端（背景執行，不阻塞 UI）
    Task {
      await syncToCloud()
    }
  }
  
  // 計算 EXP 百分比（0.0 ~ 1.0）
  var expPercentage: Double {
    guard expToNext > 0 else { return 0.0 }
    return min(Double(exp) / Double(expToNext), 1.0)
  }
  
  // MARK: - 雲端同步
  
  /// 從 Supabase 雲端載入等級與經驗值並同步到 App Group（App 啟動或登入時呼叫）
  /// 如果雲端有更新的資料，會覆蓋本地資料
  @MainActor
  func loadFromCloud() async {
    // 檢查是否有登入
    guard let authService = authService,
          authService.isLoggedIn,
          let userId = authService.currentUserId else {
      print("⚠️ [Cloud Load] 未登入或無法取得 user.id，跳過雲端載入")
      return
    }
    
    let client = authService.getClient()
    
    do {
      // 從 Supabase 查詢用戶資料
      struct ProfileResponse: Decodable {
        let level: Int?
        let current_exp: Int?
        
        enum CodingKeys: String, CodingKey {
          case level
          case current_exp = "current_exp"
        }
      }
      
      let response: [ProfileResponse] = try await client
        .from("user_profiles")
        .select("\(AppGroup.SupabaseFields.level), \(AppGroup.SupabaseFields.currentExp)")
        .eq(AppGroup.SupabaseFields.userId, value: userId)
        .execute()
        .value
      
      if let profile = response.first,
         let cloudLevel = profile.level,
         let cloudExp = profile.current_exp {
        // 如果雲端資料存在，更新本地資料
        let oldLevel = level
        let oldExp = exp
        
        // 更新等級和經驗值
        level = max(cloudLevel, 1) // 至少為 1
        exp = max(cloudExp, 0) // 至少為 0
        
        // 計算 expToNext
        expToNext = ExperienceStore.calculateExpToNext(for: level)
        
        // 使用批次同步方法，避免多次刷新
        // 不立即刷新 Widget，因為可能還有其他資料需要同步
        await MainActor.run {
          authService.saveExpToAppGroup(level: level, exp: exp, expToNext: expToNext, shouldReloadWidget: false)
        }
        
        #if DEBUG
        if oldLevel != level || oldExp != exp {
          print("✅ [Cloud Load] 已從雲端載入並更新 - Level: \(oldLevel) → \(level), EXP: \(oldExp) → \(exp)")
        } else {
          print("✅ [Cloud Load] 雲端資料與本地一致 - Level: \(level), EXP: \(exp)")
        }
        #endif
        
        // 在資料同步完成後，統一觸發一次 Widget 刷新
        await MainActor.run {
          WidgetReloader.reloadAll()
        }
      } else {
        print("⚠️ [Cloud Load] 雲端無用戶資料，使用本地資料")
      }
    } catch {
      print("❌ [Cloud Load] 載入失敗: \(error.localizedDescription)")
    }
  }
  
  /// 將等級與經驗值同步到 Supabase 雲端
  /// 使用 upsert 確保資料存在時更新，不存在時插入
  @MainActor
  func syncToCloud() async {
    // 檢查是否有登入
    guard let authService = authService,
          authService.isLoggedIn,
          let userId = authService.currentUserId else {
      print("⚠️ [Cloud Sync] 未登入或無法取得 user.id，跳過雲端同步")
      return
    }
    
    let client = authService.getClient()
    
    do {
      let displayName = authService.currentUserDisplayName ?? "使用者"
      struct ProfileUpdate: Encodable {
        let display_name: String
        let level: Int
        let current_exp: Int
        let weekly_exp: Int
        let updated_at: Date

        enum CodingKeys: String, CodingKey {
          case display_name, level, current_exp, weekly_exp, updated_at
        }
      }
      struct ProfileInsert: Encodable {
        let user_id: UUID
        let display_name: String
        let level: Int
        let current_exp: Int
        let weekly_exp: Int
        let updated_at: Date

        enum CodingKeys: String, CodingKey {
          case user_id, display_name, level, current_exp, weekly_exp, updated_at
        }
      }
      let insertPayload = ProfileInsert(
        user_id: userId,
        display_name: displayName,
        level: level,
        current_exp: exp,
        weekly_exp: weeklyExp,
        updated_at: Date()
      )
      do {
        try await client.from("user_profiles").insert(insertPayload).execute()
      } catch {
        let updatePayload = ProfileUpdate(
          display_name: displayName,
          level: level,
          current_exp: exp,
          weekly_exp: weeklyExp,
          updated_at: Date()
        )
        try await client
          .from("user_profiles")
          .update(updatePayload)
          .eq(AppGroup.SupabaseFields.userId, value: userId)
          .execute()
      }
      #if DEBUG
      print("✅ [Cloud Sync] 成功同步等級與經驗值到雲端 - Level: \(level), EXP: \(exp)")
      #endif
      
      // 同步成功後，將資料寫入 App Group（供 Widget 讀取）
      // 使用批次同步，不立即刷新（因為 addExp 已經會觸發刷新）
      await MainActor.run {
        authService.saveExpToAppGroup(level: level, exp: exp, expToNext: expToNext, shouldReloadWidget: false)
      }
    } catch {
      print("❌ [Cloud Sync] 同步失敗: \(error.localizedDescription)")
    }
  }
}
