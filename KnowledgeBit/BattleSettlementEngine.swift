// BattleSettlementEngine.swift
// 純運算式戰鬥結算邏輯（離線/local 模式用）：
//   * 分類玩家本輪 KE 投入（加固 / 有效進攻 / 退費）
//   * 應用整輪規則：reinforce → decay+pressure → 進攻解算
//   * 為純函式 / 無副作用，方便撰寫單元測試。
//
// 雲端結算流程仍由 ViewModel 直接協調（牽涉多個 async API、retry 佇列）。

import Foundation

enum BattleSettlementEngine {
  typealias Cell = StrategicBattleViewModel.Cell

  struct LocalSettleResult {
    let cells: [Cell]
    /// 本輪實際扣除的 KE（已扣掉退費）
    let spent: Int
    /// 不可進攻而退費的 KE（不會從 budget 扣除）
    let refundable: Int
  }

  /// 結算單一 bucket：套用加固、衰退、敵方壓力、進攻解算後回傳新棋盤。
  /// - Parameter attackableIds: 呼叫端預先計算的可進攻格子集合（依 VM 的領地拓樸）；
  ///   預先求值可避免引入 actor-isolation 約束，讓本函式維持為純 / sendable。
  static func settleLocal(
    cells: [Cell],
    pendingKE: [Int: Int],
    attackableIds: Set<Int>
  ) -> LocalSettleResult {
    var board = cells
    var refundable = 0
    var validAttacks: [Int: Int] = [:]
    var reinforces: [Int: Int] = [:]

    for (id, ke) in pendingKE {
      if ke <= 0 { continue }
      let owner = board[id].owner
      if owner == .player {
        reinforces[id] = ke
      } else if attackableIds.contains(id) {
        validAttacks[id] = ke
      } else {
        refundable += ke
      }
    }

    let totalPending = pendingKE.values.reduce(0, +)
    let spent = totalPending - refundable

    // ① 加固：玩家自家格子加血，不超過上限
    for (id, ke) in reinforces {
      var c = board[id]
      c.hpNow = min(c.hpMax, c.hpNow + ke)
      board[id] = c
    }

    // ② 衰退 + 敵方壓力：所有格子先扣血；歸零者回到中立
    for i in board.indices {
      var c = board[i]
      if c.enemyPressure > 0 {
        c.hpNow = max(0, c.hpNow - c.enemyPressure)
      }
      c.hpNow = max(0, c.hpNow - c.decayPerHour)
      if c.hpNow == 0 {
        c.owner = .neutral
      }
      board[i] = c
    }

    // ③ 進攻解算：超過防禦則奪格、剩餘攻擊力轉為新格 HP
    for (id, atk) in validAttacks {
      var c = board[id]
      let defHP = c.hpNow
      if atk > defHP {
        c.owner = .player
        c.hpNow = min(c.hpMax, atk - defHP)
      } else {
        c.hpNow = max(0, defHP - atk)
        if c.hpNow == 0 { c.owner = .neutral }
      }
      board[id] = c
    }

    return LocalSettleResult(cells: board, spent: spent, refundable: refundable)
  }
}
