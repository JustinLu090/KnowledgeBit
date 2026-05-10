// BattleConstants.swift
// 戰鬥（4×4 戰略地圖、非同步挑戰）相關的數值常數，集中管理以便調參與測試。

import Foundation

nonisolated enum BattleConstants {
  // MARK: - Bucket / 結算

  /// 預設結算 bucket 長度 = 1 小時
  static let defaultBucketSeconds: Int = 3600
  /// 結算 bucket 最小允許值（避免測試縮短時為 0）
  static let minBucketSeconds: Int = 60
  /// 整點前鎖定秒數（hourly 模式）
  static let hourlyLockoutSeconds: Int = 120
  /// 縮短模式（測試）下的鎖定秒數
  static let shortBucketLockoutSeconds: Int = 10

  // MARK: - Board

  /// 棋盤格數（4×4）
  static let totalCells: Int = 16
  /// 邊長（4×4 → 4）
  static let boardSide: Int = 4

  // MARK: - HP / KE

  /// 每格 KE 上限（與後端 hp_max 對齊）
  static let perCellKECap: Int = 400
  /// 預設玩家初始 KE（VM 初始化用）
  static let defaultInitialKE: Int = 1000
  /// 一般格起始 HP
  static let defaultCellHP: Int = 120
  /// 一般格 HP 上限
  static let defaultCellMaxHP: Int = 400
  /// 起始格固定 HP（左上紅、右下藍出發；不扣血）
  static let startingCellHP: Int = 100
  /// 每輪 HP 自然衰退
  static let defaultDecayPerHour: Int = 10
  /// 敵方 KE 壓力候選值（每輪自隨機集合中挑出）
  static let enemyPressureLevels: [Int] = [30, 60, 90]
  /// 敵方壓力每輪施加的格數
  static let enemyPressureCount: Int = 3

  // MARK: - UI

  /// 一鍵分配建議的單格 KE
  static let autoAllocateSuggestion: Int = 150
}

/// 非同步挑戰結束時的 EXP 發放規則。
nonisolated enum ChallengeRewards {
  static let win: Int = 30
  static let tie: Int = 15
  static let lose: Int = 10
}
