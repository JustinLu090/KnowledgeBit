import XCTest
@testable import KnowledgeBit

final class DailyQuestModelTests: XCTestCase {

  func testProgressPercentageZeroWhenTargetZero() {
    let q = DailyQuest(title: "t", targetValue: 0, currentProgress: 5, rewardExp: 10, iconName: "x")
    XCTAssertEqual(q.progressPercentage, 0)
  }

  func testProgressPercentageClampedToOne() {
    let q = DailyQuest(title: "t", targetValue: 10, currentProgress: 50, rewardExp: 10, iconName: "x")
    XCTAssertEqual(q.progressPercentage, 1.0)
  }

  func testProgressPercentageMidway() {
    let q = DailyQuest(title: "t", targetValue: 10, currentProgress: 3, rewardExp: 10, iconName: "x")
    XCTAssertEqual(q.progressPercentage, 0.3, accuracy: 0.0001)
  }

  func testUpdateProgressBinaryWhenTargetIsOne() {
    var q = DailyQuest(title: "t", targetValue: 1, currentProgress: 0, rewardExp: 20, iconName: "x")
    q.updateProgress(99)
    XCTAssertEqual(q.currentProgress, 1)
    XCTAssertTrue(q.isCompleted)
    q.updateProgress(0)
    XCTAssertEqual(q.currentProgress, 0)
    XCTAssertFalse(q.isCompleted)
  }

  func testUpdateProgressUnboundedWhenTargetGreaterThanOne() {
    var q = DailyQuest(title: "t", targetValue: 30, currentProgress: 0, rewardExp: 10, iconName: "x")
    q.updateProgress(15)
    XCTAssertEqual(q.currentProgress, 15)
    XCTAssertFalse(q.isCompleted)
  }

  func testDisplayTitleMapsKnownQuestTitles() {
    let perfect = DailyQuest(title: "單字集複習全對", targetValue: 1, rewardExp: 20, iconName: "x")
    XCTAssertEqual(perfect.displayTitle, "單字複習：完美達成")
    let mc = DailyQuest(title: "選擇題測驗全對", targetValue: 1, rewardExp: 20, iconName: "x")
    XCTAssertEqual(mc.displayTitle, "選擇題挑戰：全對")
    let other = DailyQuest(title: "學習時長 5 分鐘", targetValue: 5, rewardExp: 20, iconName: "x")
    XCTAssertEqual(other.displayTitle, "學習時長 5 分鐘")
  }
}
