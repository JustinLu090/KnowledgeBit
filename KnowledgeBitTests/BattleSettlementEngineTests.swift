import XCTest
@testable import KnowledgeBit

/// 對 BattleSettlementEngine.settleLocal 的純函式測試。
/// 結算順序：reinforce → decay+pressure → attack。
final class BattleSettlementEngineTests: XCTestCase {

  typealias Cell = StrategicBattleViewModel.Cell

  // MARK: - Reinforce

  func testReinforceIncreasesPlayerCellHP() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .player, hpNow: 100, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 50], attackableIds: []
    )
    // 100 + 50 (reinforce) - 10 (decay) = 140
    XCTAssertEqual(result.cells[5].hpNow, 140)
    XCTAssertEqual(result.cells[5].owner, .player)
    XCTAssertEqual(result.spent, 50)
    XCTAssertEqual(result.refundable, 0)
  }

  func testReinforceCappedAtHPMax() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .player, hpNow: 380, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 100], attackableIds: []
    )
    // min(400, 380+100) = 400, then -10 = 390
    XCTAssertEqual(result.cells[5].hpNow, 390)
    XCTAssertEqual(result.spent, 100)
  }

  // MARK: - Refundable

  func testRefundableForUnreachableEnemyCell() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .enemy, hpNow: 100, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 80], attackableIds: []
    )
    XCTAssertEqual(result.spent, 0)
    XCTAssertEqual(result.refundable, 80)
    // 沒有進攻；只有衰退
    XCTAssertEqual(result.cells[5].hpNow, 90)
    XCTAssertEqual(result.cells[5].owner, .enemy)
  }

  func testRefundableMixedWithValidSpend() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .player, hpNow: 100, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    cells[6] = Cell(id: 6, owner: .enemy, hpNow: 100, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 50, 6: 30], attackableIds: []
    )
    XCTAssertEqual(result.spent, 50)
    XCTAssertEqual(result.refundable, 30)
  }

  // MARK: - Decay & Pressure

  func testDecayReducesAllCells() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .player, hpNow: 50, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    cells[10] = Cell(id: 10, owner: .enemy, hpNow: 100, hpMax: 400, decayPerHour: 15, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [:], attackableIds: []
    )
    XCTAssertEqual(result.cells[5].hpNow, 40)
    XCTAssertEqual(result.cells[10].hpNow, 85)
  }

  func testDecayToZeroBecomesNeutral() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .enemy, hpNow: 5, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [:], attackableIds: []
    )
    XCTAssertEqual(result.cells[5].hpNow, 0)
    XCTAssertEqual(result.cells[5].owner, .neutral)
  }

  func testEnemyPressureAdditiveToDecay() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .player, hpNow: 100, hpMax: 400, decayPerHour: 10, enemyPressure: 30)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [:], attackableIds: []
    )
    // 100 - 30 (pressure) - 10 (decay) = 60
    XCTAssertEqual(result.cells[5].hpNow, 60)
    XCTAssertEqual(result.cells[5].owner, .player)
  }

  // MARK: - Attack

  func testAttackGreaterThanDefenseConquers() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .enemy, hpNow: 50, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 100], attackableIds: [5]
    )
    // 衰退後 defHP = 40；atk(100) > 40 → 奪格；hp = min(400, 100-40) = 60
    XCTAssertEqual(result.cells[5].owner, .player)
    XCTAssertEqual(result.cells[5].hpNow, 60)
    XCTAssertEqual(result.spent, 100)
  }

  func testAttackEqualToDefenseLeavesNeutral() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .enemy, hpNow: 30, hpMax: 400, decayPerHour: 0, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 30], attackableIds: [5]
    )
    // defHP=30；atk == defHP → 不大於 → reduce 分支；hp = max(0, 30-30) = 0；neutral
    XCTAssertEqual(result.cells[5].owner, .neutral)
    XCTAssertEqual(result.cells[5].hpNow, 0)
  }

  func testAttackLessThanDefenseReducesHP() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .enemy, hpNow: 100, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 50], attackableIds: [5]
    )
    // 衰退後 defHP=90；atk(50) < 90 → hp = 90-50 = 40
    XCTAssertEqual(result.cells[5].owner, .enemy)
    XCTAssertEqual(result.cells[5].hpNow, 40)
  }

  func testConqueredCellHPCappedAtMax() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .enemy, hpNow: 0, hpMax: 100, decayPerHour: 0, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 500], attackableIds: [5]
    )
    // 衰退階段：hp=0 → 變 neutral；attack 階段：defHP=0；atk(500) > 0 → 奪格；hp = min(100, 500) = 100
    XCTAssertEqual(result.cells[5].owner, .player)
    XCTAssertEqual(result.cells[5].hpNow, 100)
  }

  // MARK: - Order of Operations

  func testReinforceAppliedBeforeDecay() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .player, hpNow: 5, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 20], attackableIds: []
    )
    // 沒加固：5-10 = -5 → 0 → neutral；加固後：5+20=25 → 25-10=15 → 仍 player
    XCTAssertEqual(result.cells[5].hpNow, 15)
    XCTAssertEqual(result.cells[5].owner, .player)
  }

  func testAttackTargetTakesDecayBeforeAttack() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .enemy, hpNow: 50, hpMax: 400, decayPerHour: 30, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 20], attackableIds: [5]
    )
    // 衰退後 defHP=20；atk(20) == defHP → 0 → neutral
    XCTAssertEqual(result.cells[5].owner, .neutral)
    XCTAssertEqual(result.cells[5].hpNow, 0)
  }

  // MARK: - Edge Cases

  func testEmptyPendingProducesZeroSpentAndRefundable() {
    let cells = neutralBoard()
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [:], attackableIds: []
    )
    XCTAssertEqual(result.spent, 0)
    XCTAssertEqual(result.refundable, 0)
  }

  func testZeroKEEntryIgnored() {
    var cells = neutralBoard()
    cells[5] = Cell(id: 5, owner: .player, hpNow: 100, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    let result = BattleSettlementEngine.settleLocal(
      cells: cells, pendingKE: [5: 0], attackableIds: []
    )
    XCTAssertEqual(result.spent, 0)
    XCTAssertEqual(result.refundable, 0)
    // 仍會走衰退
    XCTAssertEqual(result.cells[5].hpNow, 90)
  }

  // MARK: - Helpers

  private func neutralBoard() -> [Cell] {
    (0..<16).map { id in
      Cell(id: id, owner: .neutral, hpNow: 50, hpMax: 400, decayPerHour: 10, enemyPressure: 0)
    }
  }
}
