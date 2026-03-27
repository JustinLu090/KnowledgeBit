import XCTest
@testable import KnowledgeBit

final class WordSetIconTypeTests: XCTestCase {

  func testAllCasesCount() {
    XCTAssertEqual(WordSetIconType.allCases.count, 2)
  }

  func testIdsMatchRawValue() {
    XCTAssertEqual(WordSetIconType.emoji.id, "emoji")
    XCTAssertEqual(WordSetIconType.image.id, "image")
  }

  func testDisplayNames() {
    XCTAssertEqual(WordSetIconType.emoji.displayName, "Emoji")
    XCTAssertEqual(WordSetIconType.image.displayName, "圖片")
  }

  func testCodableRoundTrip() throws {
    for original in WordSetIconType.allCases {
      let data = try JSONEncoder().encode(original)
      let decoded = try JSONDecoder().decode(WordSetIconType.self, from: data)
      XCTAssertEqual(decoded, original)
    }
  }
}
