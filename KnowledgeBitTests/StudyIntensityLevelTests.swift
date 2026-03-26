import XCTest
@testable import KnowledgeBit

final class StudyIntensityLevelTests: XCTestCase {

  func testFromCardCountBoundaries() {
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 0), .none)
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 1), .low)
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 2), .low)
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 3), .medium)
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 5), .medium)
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 6), .high)
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 9), .high)
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 10), .max)
    XCTAssertEqual(StudyIntensityLevel.from(cardCount: 100), .max)
  }
}
