import XCTest
@testable import KnowledgeBit

/// 七項每日任務池：與 `DailyQuestCatalog` 對照，變更任務數值時測試會失敗以提醒同步。
final class DailyQuestCatalogTests: XCTestCase {

  func testPoolCountIsSeven() {
    XCTAssertEqual(DailyQuestCatalog.poolCount, 7)
    XCTAssertEqual(DailyQuestCatalog.definitions.count, 7)
  }

  func testAllSevenTitlesTargetsRewardsIcons() {
    let titles = [
      "學習時長 5 分鐘",
      "完成一本單字集複習",
      "完成兩本單字集複習",
      "單字集複習答對率超過 90%",
      "單字集複習全對",
      "選擇題測驗全對",
      "獲得 30 經驗值"
    ]
    let targets = [5, 1, 2, 1, 1, 1, 30]
    let rewards = [20, 15, 25, 15, 20, 20, 10]
    let icons = [
      "clock.fill",
      "book.fill",
      "books.vertical.fill",
      "percent",
      "checkmark.circle.fill",
      "list.bullet.circle.fill",
      "bolt.fill"
    ]
    XCTAssertEqual(DailyQuestCatalog.definitions.map(\.title), titles)
    XCTAssertEqual(DailyQuestCatalog.definitions.map(\.targetValue), targets)
    XCTAssertEqual(DailyQuestCatalog.definitions.map(\.rewardExp), rewards)
    XCTAssertEqual(DailyQuestCatalog.definitions.map(\.iconName), icons)
  }

  func testTitlesAreUnique() {
    let titles = DailyQuestCatalog.definitions.map(\.title)
    XCTAssertEqual(Set(titles).count, titles.count)
  }

  func testEachSlotBuildsDailyQuestWithMatchingFields() {
    for (i, d) in DailyQuestCatalog.definitions.enumerated() {
      let q = DailyQuest(
        title: d.title,
        targetValue: d.targetValue,
        currentProgress: 0,
        rewardExp: d.rewardExp,
        iconName: d.iconName
      )
      XCTAssertEqual(q.title, d.title, "index \(i)")
      XCTAssertEqual(q.targetValue, d.targetValue, "index \(i)")
      XCTAssertEqual(q.rewardExp, d.rewardExp, "index \(i)")
      XCTAssertEqual(q.iconName, d.iconName, "index \(i)")
      XCTAssertFalse(q.isCompleted, "index \(i)")
      XCTAssertEqual(q.progressPercentage, 0, accuracy: 0.0001, "index \(i)")
    }
  }

  func testDisplayTitleForPerfectQuestSlotsFourAndFive() {
    XCTAssertEqual(
      DailyQuest(
        title: DailyQuestCatalog.definitions[4].title,
        targetValue: 1,
        rewardExp: 20,
        iconName: "x"
      ).displayTitle,
      "單字複習：完美達成"
    )
    XCTAssertEqual(
      DailyQuest(
        title: DailyQuestCatalog.definitions[5].title,
        targetValue: 1,
        rewardExp: 20,
        iconName: "x"
      ).displayTitle,
      "選擇題挑戰：全對"
    )
  }

  func testRandomSelectionOnlyUsesValidIndices() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    for day in 1...14 {
      let d = try XCTUnwrap(
        DateComponents(calendar: cal, year: 2025, month: 6, day: day).date
      )
      let idx = DailyQuestRandomSelection.indices(for: d)
      XCTAssertEqual(idx.count, 3)
      XCTAssertTrue(idx.allSatisfy { (0..<DailyQuestCatalog.poolCount).contains($0) })
    }
  }
}
