import XCTest
@testable import KnowledgeBit

final class SRSRulesTests: XCTestCase {

  func testMutationRememberedFromLevelZero() {
    let m = SRSRules.mutation(oldLevel: 0, oldCorrectStreak: 0, result: .remembered)
    XCTAssertEqual(m.newLevel, 1)
    XCTAssertEqual(m.newCorrectStreak, 1)
    XCTAssertEqual(m.dueInterval, 24 * 60 * 60, accuracy: 0.001)
  }

  func testMutationForgottenResets() {
    let m = SRSRules.mutation(oldLevel: 4, oldCorrectStreak: 3, result: .forgotten)
    XCTAssertEqual(m.newLevel, 0)
    XCTAssertEqual(m.newCorrectStreak, 0)
    XCTAssertEqual(m.dueInterval, 10 * 60, accuracy: 0.001)
  }

  func testMutationRememberedFromLevelFive() {
    let m = SRSRules.mutation(oldLevel: 5, oldCorrectStreak: 2, result: .remembered)
    XCTAssertEqual(m.newLevel, 6)
    XCTAssertEqual(m.newCorrectStreak, 3)
    XCTAssertEqual(m.dueInterval, 30 * 24 * 60 * 60, accuracy: 0.001)
  }

  func testIntervalForHighLevelsIncreasesByThirtyDays() {
    XCTAssertEqual(SRSRules.intervalForLevel(6), TimeInterval(30 * 24 * 60 * 60), accuracy: 0.001)
    XCTAssertEqual(SRSRules.intervalForLevel(7), TimeInterval(60 * 24 * 60 * 60), accuracy: 0.001)
  }

  func testIntervalForLevelsOneThroughFive() {
    XCTAssertEqual(SRSRules.intervalForLevel(1), 24 * 60 * 60, accuracy: 0.001)
    XCTAssertEqual(SRSRules.intervalForLevel(2), 3 * 24 * 60 * 60, accuracy: 0.001)
    XCTAssertEqual(SRSRules.intervalForLevel(3), 7 * 24 * 60 * 60, accuracy: 0.001)
    XCTAssertEqual(SRSRules.intervalForLevel(4), 14 * 24 * 60 * 60, accuracy: 0.001)
    XCTAssertEqual(SRSRules.intervalForLevel(5), 30 * 24 * 60 * 60, accuracy: 0.001)
  }

  func testMutationRememberedIncrementsStreak() {
    let m = SRSRules.mutation(oldLevel: 2, oldCorrectStreak: 5, result: .remembered)
    XCTAssertEqual(m.newLevel, 3)
    XCTAssertEqual(m.newCorrectStreak, 6)
  }
}
