import XCTest
@testable import KnowledgeBit

final class StudyLogStreakTests: XCTestCase {

  private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = 0
    comps.second = 0
    return utcCalendar.date(from: comps)!
  }

  func testEmptyLogsReturnsZero() {
    let logs: [StudyLog] = []
    XCTAssertEqual(logs.currentStreak(referenceNow: date(year: 2025, month: 3, day: 15), calendar: utcCalendar), 0)
  }

  func testSingleStreakToday() {
    let ref = date(year: 2025, month: 3, day: 15)
    let logs = [StudyLog(date: ref, cardsReviewed: 1, totalCards: 1)]
    XCTAssertEqual(logs.currentStreak(referenceNow: ref, calendar: utcCalendar), 1)
  }

    func testThreeConsecutiveDays() {
      let ref = date(year: 2025, month: 3, day: 15)
      let logs = [
        StudyLog(date: ref, cardsReviewed: 1, totalCards: 1),
        StudyLog(date: date(year: 2025, month: 3, day: 14), cardsReviewed: 1, totalCards: 1),
        StudyLog(date: date(year: 2025, month: 3, day: 13), cardsReviewed: 1, totalCards: 1),
      ]
      XCTAssertEqual(logs.currentStreak(referenceNow: ref, calendar: utcCalendar), 3)
    }
    
  func testGapBreaksStreak() {
    let ref = date(year: 2025, month: 3, day: 15)
    let logs = [
      StudyLog(date: ref, cardsReviewed: 1, totalCards: 1),
      StudyLog(date: date(year: 2025, month: 3, day: 14), cardsReviewed: 1, totalCards: 1),
      StudyLog(date: date(year: 2025, month: 3, day: 12), cardsReviewed: 1, totalCards: 1),
    ]
    XCTAssertEqual(logs.currentStreak(referenceNow: ref, calendar: utcCalendar), 2)
  }

  func testNoStudyTodayBreaksEvenIfYesterdayExists() {
    let ref = date(year: 2025, month: 3, day: 15)
    let logs = [StudyLog(date: date(year: 2025, month: 3, day: 14), cardsReviewed: 1, totalCards: 1)]
    XCTAssertEqual(logs.currentStreak(referenceNow: ref, calendar: utcCalendar), 0)
  }

  func testMultipleLogsSameDayCountOnce() {
    let ref = date(year: 2025, month: 3, day: 15)
    let logs = [
      StudyLog(date: ref, cardsReviewed: 1, totalCards: 1),
      StudyLog(date: date(year: 2025, month: 3, day: 15, hour: 20), cardsReviewed: 2, totalCards: 2),
    ]
    XCTAssertEqual(logs.currentStreak(referenceNow: ref, calendar: utcCalendar), 1)
  }
}
