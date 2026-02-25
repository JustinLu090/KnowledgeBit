// StrategicBattleViewModel.swift
// Hourly strategic grid battle simulation (front-end focused)

import Foundation
import SwiftUI
import Combine

@MainActor
final class StrategicBattleViewModel: ObservableObject {
  enum Owner: String, Codable {
    case neutral
    case player
    case enemy
  }

  struct Cell: Identifiable, Equatable {
    let id: Int // 0...15
    var owner: Owner
    var hpNow: Int
    var hpMax: Int
    var decayPerHour: Int

    // For UI effects
    var enemyPressure: Int // enemy KE投入（用來觸發 UnderAttack 視覺）
  }

  // MARK: - Published state

  @Published private(set) var cells: [Cell] = []
  @Published var selectedCellID: Int? = nil

  /// 玩家本小時暫存（未結算）分配：cellID -> KE
  @Published private(set) var pendingKE: [Int: Int] = [:]

  /// 本小時玩家可用積分（KE）總額
  @Published private(set) var hourlyBudget: Int = 1000

  /// 距整點結算秒數
  @Published private(set) var secondsToTopOfHour: Int = 0

  /// 整點前最後 2 分鐘鎖定
  @Published private(set) var isSettlementLocked: Bool = false

  private var timerCancellable: AnyCancellable?
  private var nowProvider: () -> Date

  // MARK: - Init

  init(nowProvider: @escaping () -> Date = { Date() }) {
    self.nowProvider = nowProvider
    self.bootstrapInitialBoard()
    self.startTimer()
    self.refreshCountdown()
  }

  deinit {
    timerCancellable?.cancel()
  }

  // MARK: - Derived

  var remainingKE: Int {
    max(0, hourlyBudget - pendingKE.values.reduce(0, +))
  }

  var occupiedCount: Int {
    cells.filter { $0.owner == .player }.count
  }

  var totalInvestedThisHour: Int {
    pendingKE.values.reduce(0, +)
  }

  // MARK: - Public API

  func cell(for id: Int) -> Cell {
    cells[id]
  }

  func setSelected(cellID: Int?) {
    guard !isSettlementLocked else { return }
    selectedCellID = cellID
  }

  // MARK: - Neighbor / Reachability

  func neighbors(of id: Int) -> [Int] {
    let row = id / 4
    let col = id % 4
    var n: [Int] = []
    if row > 0 { n.append((row - 1) * 4 + col) }      // up
    if row < 3 { n.append((row + 1) * 4 + col) }      // down
    if col > 0 { n.append(row * 4 + (col - 1)) }      // left
    if col < 3 { n.append(row * 4 + (col + 1)) }      // right
    return n
  }

  func isEdgeCell(_ id: Int) -> Bool {
    let row = id / 4
    let col = id % 4
    return row == 0 || row == 3 || col == 0 || col == 3
  }

  /// 可進攻：與己方領地相鄰（若玩家被全滅/領地為0，外環全部可進攻）
  func isAttackableTarget(_ id: Int) -> Bool {
    let c = cells[id]
    if c.owner == .player { return false }
    if occupiedCount == 0 { return isEdgeCell(id) }   // 全滅後重新開局：外環可進攻
    return neighbors(of: id).contains(where: { cells[$0].owner == .player })
  }

  /// 不可觸及：非己方且不可進攻
  func isLockedCell(_ id: Int) -> Bool {
    let c = cells[id]
    if c.owner == .player { return false }
    return !isAttackableTarget(id)
  }

  func isUnderAttack(_ id: Int) -> Bool {
    cells[id].enemyPressure > 0
  }

  func pendingValue(for id: Int) -> Int {
    pendingKE[id, default: 0]
  }

  /// 更新選取格子的投入 KE（會自動 clamp 到剩餘可用）
  func updatePendingKE(for id: Int, to newValue: Int) {
    guard !isSettlementLocked else { return }
    let clamped = max(0, newValue)

    // 先移除舊值，再檢查剩餘額度
    let othersSum = pendingKE
      .filter { $0.key != id }
      .map { $0.value }
      .reduce(0, +)

    let maxAllowed = max(0, hourlyBudget - othersSum)
    let finalValue = min(clamped, maxAllowed)

    if finalValue == 0 {
      pendingKE.removeValue(forKey: id)
    } else {
      pendingKE[id] = finalValue
    }
  }

  /// 依企劃：HP_next = HP_now + KE_in − KE_out − Decay
  func predictedHPNext(for id: Int) -> Int {
    let c = cells[id]
    let keIn = (c.owner == .player) ? pendingValue(for: id) : 0
    let keOut = c.enemyPressure
    let next = c.hpNow + keIn - keOut - c.decayPerHour
    return max(0, min(c.hpMax, next))
  }

  // MARK: - Settlement

  func settleHour() {
    // 1) 路徑有效性檢查（簡化版）
    //    - 只有「當下仍為 attackable」的目標才算有效，否則退回
    var refundable = 0
    var validAttacks: [Int: Int] = [:]
    var reinforces: [Int: Int] = [:]

    for (id, ke) in pendingKE {
      if ke <= 0 { continue }
      let owner = cells[id].owner
      if owner == .player {
        reinforces[id] = ke
      } else {
        if isAttackableTarget(id) {
          validAttacks[id] = ke
        } else {
          refundable += ke
        }
      }
    }

    // 2) 扣除消耗、退回無效投入
    let spent = pendingKE.values.reduce(0, +) - refundable
    hourlyBudget = max(0, hourlyBudget - spent) + refundable

    // 3) 加固：HP 增加（上限 hpMax）
    for (id, ke) in reinforces {
      var c = cells[id]
      c.hpNow = min(c.hpMax, c.hpNow + ke)
      cells[id] = c
    }

    // 4) 先承受 enemyPressure + decay
    for i in cells.indices {
      var c = cells[i]
      if c.enemyPressure > 0 {
        c.hpNow = max(0, c.hpNow - c.enemyPressure)
      }
      c.hpNow = max(0, c.hpNow - c.decayPerHour)
      if c.hpNow == 0 {
        c.owner = .neutral
      }
      cells[i] = c
    }

    // 5) 進攻：攻擊KE vs 守方HP
    for (id, atk) in validAttacks {
      var c = cells[id]
      let defHP = c.hpNow

      if atk > defHP {
        c.owner = .player
        c.hpNow = min(c.hpMax, atk - defHP)
      } else {
        c.hpNow = max(0, defHP - atk)
        if c.hpNow == 0 { c.owner = .neutral }
      }
      cells[id] = c
    }

    // 6) 重置本小時暫存，重新抽敵方壓力
    pendingKE.removeAll()
    selectedCellID = nil
    rollEnemyPressure()

    // 7) 每小時回補到 1000（可之後再換成你要的規則）
    hourlyBudget = 1000

    // 若被全滅：保留「外環可進攻」規則（不自動給角落），由 UI 提示玩家重新擴張
    WidgetReloader.reloadAll()
  }

  // MARK: - Timer & Countdown

  private func startTimer() {
    timerCancellable?.cancel()
    timerCancellable = Timer
      .publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        guard let self else { return }
        self.tick()
      }
  }

  private func tick() {
    refreshCountdown()
    isSettlementLocked = secondsToTopOfHour <= 120
    if secondsToTopOfHour <= 0 {
      settleHour()
      refreshCountdown()
    }
  }

  private func refreshCountdown() {
    let now = nowProvider()
    let cal = Calendar.current
    var comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
    comps.minute = 0
    comps.second = 0
    let thisHourTop = cal.date(from: comps) ?? now
    let nextHourTop = cal.date(byAdding: .hour, value: 1, to: thisHourTop) ?? now.addingTimeInterval(3600)
    let diff = Int(nextHourTop.timeIntervalSince(now))
    secondsToTopOfHour = max(0, diff)
  }

  // MARK: - Board bootstrap (UPDATED)

  private func bootstrapInitialBoard() {
    // 初始：隨機生成少量敵方；然後若玩家沒有領地，直接給一個「空的角落」當基地
    let hpMax = 400
    cells = (0..<16).map { id in
      let isEnemy = (id % 7 == 0) // sparse
      return Cell(
        id: id,
        owner: isEnemy ? .enemy : .neutral,
        hpNow: isEnemy ? 220 : 120,
        hpMax: hpMax,
        decayPerHour: 10,
        enemyPressure: 0
      )
    }

    ensureInitialCornerForPlayer()
    rollEnemyPressure()
  }

  /// ✅ 新需求：一開始沒有領地 → 直接在四角找一個「沒有人的角落」分配給玩家（預設藍隊）
  private func ensureInitialCornerForPlayer() {
    guard occupiedCount == 0 else { return }

    let corners = [0, 3, 12, 15]
    // 找非敵方的角落（neutral），直接給玩家
    if let pick = corners.first(where: { cells[$0].owner == .neutral }) {
      var c = cells[pick]
      c.owner = .player
      c.hpNow = max(c.hpNow, 240)   // 起始基地 HP（你可調）
      c.enemyPressure = 0
      cells[pick] = c
      return
    }

    // 若四角都被敵方佔（極端情況），強制把第一個角落轉為 neutral 再給玩家
    if let fallback = corners.first {
      var c = cells[fallback]
      c.owner = .player
      c.hpNow = 240
      c.enemyPressure = 0
      cells[fallback] = c
    }
  }

  private func rollEnemyPressure() {
    var newCells = cells
    for i in newCells.indices { newCells[i].enemyPressure = 0 }

    let candidates = (0..<16).filter { newCells[$0].owner != .player }
    let picks = candidates.shuffled().prefix(3)
    for id in picks {
      newCells[id].enemyPressure = [30, 60, 90].randomElement() ?? 60
    }
    cells = newCells
  }
}
