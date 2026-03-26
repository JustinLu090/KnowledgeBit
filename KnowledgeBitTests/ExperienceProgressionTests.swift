import XCTest
@testable import KnowledgeBit

final class ExperienceProgressionTests: XCTestCase {

  func testLevel1Requires100Exp() {
    XCTAssertEqual(ExperienceProgression.expRequiredToAdvance(fromLevel: 1), 100)
  }

  func testLevel2Requires120Exp() {
    XCTAssertEqual(ExperienceProgression.expRequiredToAdvance(fromLevel: 2), 120)
  }

  func testLevel3Requires144Exp() {
    XCTAssertEqual(ExperienceProgression.expRequiredToAdvance(fromLevel: 3), 144)
  }

  func testNeverBelow100() {
    XCTAssertGreaterThanOrEqual(ExperienceProgression.expRequiredToAdvance(fromLevel: 99), 100)
  }
}
