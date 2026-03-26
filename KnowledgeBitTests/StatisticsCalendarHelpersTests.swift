import XCTest
@testable import KnowledgeBit

final class StatisticsCalendarHelpersTests: XCTestCase {

  private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  func testWeekContainingSundayStartsThatSunday() throws {
    var comps = DateComponents()
    comps.calendar = utcCalendar
    comps.year = 2025
    comps.month = 3
    comps.day = 23
    comps.hour = 12
    let sunday = try XCTUnwrap(utcCalendar.date(from: comps))
    let start = StatisticsCalendarHelpers.weekStartSunday(containing: sunday, calendar: utcCalendar)
    XCTAssertTrue(utcCalendar.isDate(start, inSameDayAs: sunday))
  }

  func testWeekContainingWednesdayRollsBackToSunday() throws {
    var comps = DateComponents()
    comps.calendar = utcCalendar
    comps.year = 2025
    comps.month = 3
    comps.day = 26
    comps.hour = 12
    let wednesday = try XCTUnwrap(utcCalendar.date(from: comps))
    let start = StatisticsCalendarHelpers.weekStartSunday(containing: wednesday, calendar: utcCalendar)

    var sunComps = DateComponents()
    sunComps.calendar = utcCalendar
    sunComps.year = 2025
    sunComps.month = 3
    sunComps.day = 23
    let expectedSunday = try XCTUnwrap(utcCalendar.date(from: sunComps))
    XCTAssertTrue(utcCalendar.isDate(start, inSameDayAs: expectedSunday))
  }
}
