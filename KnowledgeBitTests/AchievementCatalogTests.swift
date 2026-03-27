import XCTest
@testable import KnowledgeBit

final class AchievementCatalogTests: XCTestCase {

  func testCatalogIdsAreUnique() {
    let ids = AchievementService.catalog.map(\.id)
    XCTAssertEqual(Set(ids).count, ids.count)
  }

  func testCatalogIdsMatchConditionDictionaryKeys() {
    let catalogIds = Set(AchievementService.catalog.map(\.id))
    let allMet = AchievementService.achievementConditions(
      level: 100,
      streak: 100,
      quizzes: 10_000,
      reviews: 10_000,
      battles: 100,
      quests: 100,
      friends: 100
    )
    XCTAssertEqual(catalogIds, Set(allMet.keys))
  }

  func testCatalogCount() {
    XCTAssertEqual(AchievementService.catalog.count, 16)
  }

  func testAchievementIsUnlockedReflectsUnlockedAt() {
    let locked = Achievement(
      id: "x",
      title: "t",
      description: "d",
      iconName: "i",
      rarity: .common,
      unlockedAt: nil
    )
    XCTAssertFalse(locked.isUnlocked)
    var unlocked = locked
    unlocked.unlockedAt = Date()
    XCTAssertTrue(unlocked.isUnlocked)
  }

  func testRarityLabels() {
    XCTAssertEqual(AchievementRarity.common.label, "普通")
    XCTAssertEqual(AchievementRarity.rare.label, "稀有")
    XCTAssertEqual(AchievementRarity.epic.label, "史詩")
    XCTAssertEqual(AchievementRarity.legendary.label, "傳說")
  }

  // MARK: - Threshold boundaries (achievementConditions)

  func testLevelThresholds() {
    func met(_ level: Int) -> [String: Bool] {
      AchievementService.achievementConditions(
        level: level, streak: 0, quizzes: 0, reviews: 0, battles: 0, quests: 0, friends: 0
      )
    }
    XCTAssertEqual(met(4)["level_5"], false)
    XCTAssertEqual(met(5)["level_5"], true)
    XCTAssertEqual(met(9)["level_10"], false)
    XCTAssertEqual(met(10)["level_10"], true)
    XCTAssertEqual(met(19)["level_20"], false)
    XCTAssertEqual(met(20)["level_20"], true)
    XCTAssertEqual(met(49)["level_50"], false)
    XCTAssertEqual(met(50)["level_50"], true)
  }

  func testStreakThresholds() {
    func met(_ streak: Int) -> [String: Bool] {
      AchievementService.achievementConditions(
        level: 0, streak: streak, quizzes: 0, reviews: 0, battles: 0, quests: 0, friends: 0
      )
    }
    XCTAssertEqual(met(2)["streak_3"], false)
    XCTAssertEqual(met(3)["streak_3"], true)
    XCTAssertEqual(met(6)["streak_7"], false)
    XCTAssertEqual(met(7)["streak_7"], true)
    XCTAssertEqual(met(29)["streak_30"], false)
    XCTAssertEqual(met(30)["streak_30"], true)
  }

  func testQuizThresholds() {
    func met(_ q: Int) -> [String: Bool] {
      AchievementService.achievementConditions(
        level: 0, streak: 0, quizzes: q, reviews: 0, battles: 0, quests: 0, friends: 0
      )
    }
    XCTAssertEqual(met(9)["quiz_10"], false)
    XCTAssertEqual(met(10)["quiz_10"], true)
    XCTAssertEqual(met(49)["quiz_50"], false)
    XCTAssertEqual(met(50)["quiz_50"], true)
  }

  func testReviewThresholds() {
    func met(_ r: Int) -> [String: Bool] {
      AchievementService.achievementConditions(
        level: 0, streak: 0, quizzes: 0, reviews: r, battles: 0, quests: 0, friends: 0
      )
    }
    XCTAssertEqual(met(99)["review_100"], false)
    XCTAssertEqual(met(100)["review_100"], true)
    XCTAssertEqual(met(499)["review_500"], false)
    XCTAssertEqual(met(500)["review_500"], true)
  }

  func testBattleThresholds() {
    func met(_ b: Int) -> [String: Bool] {
      AchievementService.achievementConditions(
        level: 0, streak: 0, quizzes: 0, reviews: 0, battles: b, quests: 0, friends: 0
      )
    }
    XCTAssertEqual(met(0)["battle_win_1"], false)
    XCTAssertEqual(met(1)["battle_win_1"], true)
    XCTAssertEqual(met(9)["battle_win_10"], false)
    XCTAssertEqual(met(10)["battle_win_10"], true)
  }

  func testFriendThreshold() {
    func met(_ f: Int) -> [String: Bool] {
      AchievementService.achievementConditions(
        level: 0, streak: 0, quizzes: 0, reviews: 0, battles: 0, quests: 0, friends: f
      )
    }
    XCTAssertEqual(met(0)["friend_1"], false)
    XCTAssertEqual(met(1)["friend_1"], true)
  }

  func testDailyQuestThresholds() {
    func met(_ q: Int) -> [String: Bool] {
      AchievementService.achievementConditions(
        level: 0, streak: 0, quizzes: 0, reviews: 0, battles: 0, quests: q, friends: 0
      )
    }
    XCTAssertEqual(met(9)["daily_quest_10"], false)
    XCTAssertEqual(met(10)["daily_quest_10"], true)
    XCTAssertEqual(met(29)["daily_quest_30"], false)
    XCTAssertEqual(met(30)["daily_quest_30"], true)
  }

  func testZeroProgressNoAchievementsMet() {
    let z = AchievementService.achievementConditions(
      level: 0, streak: 0, quizzes: 0, reviews: 0, battles: 0, quests: 0, friends: 0
    )
    XCTAssertTrue(z.values.allSatisfy { !$0 })
  }
}
