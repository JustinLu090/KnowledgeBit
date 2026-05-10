import XCTest
@testable import KnowledgeBit

/// 鎖定 BattleConstants 的設計前提。當未來有人調參時，若違反這些不變量會被 CI 攔下。
final class BattleConstantsTests: XCTestCase {

  // MARK: - Board geometry

  func testBoardSideSquared() {
    XCTAssertEqual(
      BattleConstants.boardSide * BattleConstants.boardSide,
      BattleConstants.totalCells,
      "totalCells 應等於 boardSide² (4×4=16)"
    )
  }

  // MARK: - Bucket / Lockout

  func testHourlyBucketIsExactlyOneHour() {
    XCTAssertEqual(BattleConstants.defaultBucketSeconds, 60 * 60)
  }

  func testMinBucketSecondsIsLessThanDefault() {
    XCTAssertLessThan(
      BattleConstants.minBucketSeconds,
      BattleConstants.defaultBucketSeconds,
      "minBucketSeconds 必須小於 defaultBucketSeconds，否則整點模式會被視為 short 模式"
    )
  }

  func testHourlyLockoutMustBeShorterThanBucket() {
    XCTAssertLessThan(
      BattleConstants.hourlyLockoutSeconds,
      BattleConstants.defaultBucketSeconds,
      "鎖定秒數必須小於 bucket 長度，否則會永遠處於鎖定狀態"
    )
  }

  func testShortBucketLockoutMustBeShorterThanMinBucket() {
    XCTAssertLessThan(
      BattleConstants.shortBucketLockoutSeconds,
      BattleConstants.minBucketSeconds,
      "短 bucket 模式的鎖定也須短於 bucket 本身"
    )
  }

  // MARK: - HP / KE alignment

  func testCellMaxHPMatchesPerCellKECap() {
    XCTAssertEqual(
      BattleConstants.defaultCellMaxHP,
      BattleConstants.perCellKECap,
      "格子 HP 上限與單格 KE 投入上限應對齊（後端 hp_max 與前端 cap 一致）"
    )
  }

  func testStartingCellHPNotGreaterThanDefault() {
    // 起始格 HP 應 ≤ 一般格上限（雖然起始格 hpMax 自帶較低，本測試只防荒謬值）
    XCTAssertGreaterThan(BattleConstants.startingCellHP, 0)
    XCTAssertLessThanOrEqual(
      BattleConstants.startingCellHP,
      BattleConstants.defaultCellMaxHP
    )
  }

  func testInitialKEAllowsFullCapInvestment() {
    // 預設初始 KE 應至少能對單格投入到 cap，否則「滿格進攻」永遠做不到
    XCTAssertGreaterThanOrEqual(
      BattleConstants.defaultInitialKE,
      BattleConstants.perCellKECap
    )
  }

  // MARK: - Enemy pressure

  func testEnemyPressureLevelsAllPositive() {
    XCTAssertFalse(BattleConstants.enemyPressureLevels.isEmpty)
    XCTAssertTrue(
      BattleConstants.enemyPressureLevels.allSatisfy { $0 > 0 },
      "壓力值需為正數，否則 max(0, hpNow - pressure) 沒意義"
    )
  }

  func testEnemyPressureCountFitsBoard() {
    // 隨機選 N 格施加壓力，N 不應大於非起始格總數（14）
    XCTAssertLessThanOrEqual(
      BattleConstants.enemyPressureCount,
      BattleConstants.totalCells - 2
    )
  }

  // MARK: - UI

  func testAutoAllocateSuggestionWithinCellCap() {
    XCTAssertLessThanOrEqual(
      BattleConstants.autoAllocateSuggestion,
      BattleConstants.perCellKECap,
      "一鍵分配建議不應超過單格 KE 上限"
    )
    XCTAssertGreaterThan(BattleConstants.autoAllocateSuggestion, 0)
  }

  // MARK: - Challenge rewards

  func testChallengeRewardsOrdered() {
    XCTAssertGreaterThan(ChallengeRewards.win, ChallengeRewards.tie)
    XCTAssertGreaterThan(ChallengeRewards.tie, ChallengeRewards.lose)
    XCTAssertGreaterThan(ChallengeRewards.lose, 0, "輸了至少也要給安慰獎")
  }
}
