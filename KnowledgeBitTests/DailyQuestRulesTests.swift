import XCTest
@testable import KnowledgeBit

final class DailyQuestRulesTests: XCTestCase {

  func testAccuracyQuestRequiresAtLeast90() {
    XCTAssertFalse(DailyQuestQuizRules.satisfiesAccuracyOver90(accuracyPercent: 89))
    XCTAssertTrue(DailyQuestQuizRules.satisfiesAccuracyOver90(accuracyPercent: 90))
    XCTAssertTrue(DailyQuestQuizRules.satisfiesAccuracyOver90(accuracyPercent: 100))
  }

  func testWordSetPerfectOnlyGeneralQuiz() {
    XCTAssertTrue(DailyQuestQuizRules.satisfiesWordSetPerfect(quizType: .general, isPerfect: true))
    XCTAssertFalse(DailyQuestQuizRules.satisfiesWordSetPerfect(quizType: .general, isPerfect: false))
    XCTAssertFalse(DailyQuestQuizRules.satisfiesWordSetPerfect(quizType: .multipleChoice, isPerfect: true))
  }

  func testMultipleChoicePerfectOnlyMultipleChoiceQuiz() {
    XCTAssertTrue(DailyQuestQuizRules.satisfiesMultipleChoicePerfect(quizType: .multipleChoice, isPerfect: true))
    XCTAssertFalse(DailyQuestQuizRules.satisfiesMultipleChoicePerfect(quizType: .multipleChoice, isPerfect: false))
    XCTAssertFalse(DailyQuestQuizRules.satisfiesMultipleChoicePerfect(quizType: .general, isPerfect: true))
  }

  func testRandomSelectionIsDeterministicPerDate() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let morning = try XCTUnwrap(cal.date(from: DateComponents(
      calendar: cal,
      year: 2025,
      month: 7,
      day: 4,
      hour: 8,
      minute: 30
    )))
    let evening = try XCTUnwrap(cal.date(from: DateComponents(
      calendar: cal,
      year: 2025,
      month: 7,
      day: 4,
      hour: 22,
      minute: 30
    )))
    let a = DailyQuestRandomSelection.indices(for: morning)
    let b = DailyQuestRandomSelection.indices(for: evening)
    XCTAssertEqual(a, b, "同一天內不同時間應得到相同任務索引")
  }

  func testRandomSelectionShape() throws {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let comps = DateComponents(calendar: cal, year: 2024, month: 1, day: 1)
    let d = try XCTUnwrap(cal.date(from: comps))
    let idx = DailyQuestRandomSelection.indices(for: d)
    XCTAssertEqual(idx.count, 3)
    XCTAssertEqual(Set(idx).count, 3)
    XCTAssertEqual(idx, idx.sorted())
    XCTAssertTrue(idx.allSatisfy { (0..<DailyQuestCatalog.poolCount).contains($0) })
  }

  func testRandomSelectionValidForSeveralDaysInMarch() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    for day in 1...7 {
      let d = DateComponents(calendar: cal, year: 2025, month: 3, day: day).date!
      let idx = DailyQuestRandomSelection.indices(for: d)
      XCTAssertEqual(idx.count, 3, "day \(day)")
      XCTAssertEqual(Set(idx).count, 3)
    }
  }
}
