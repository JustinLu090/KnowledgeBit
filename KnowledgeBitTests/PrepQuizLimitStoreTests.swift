import XCTest
@testable import KnowledgeBit

@MainActor
final class PrepQuizLimitStoreTests: XCTestCase {

  private var defaults: UserDefaults!
  private let suiteName = "com.knowledgebit.tests.PrepQuizLimitStore"

  /// 固定「某一天」的瞬間，避免測試跨日或受執行時刻影響
  private let fixedNow = Date(timeIntervalSince1970: 1_720_000_000)

  override func setUp() async throws {
    try await super.setUp()
    defaults = UserDefaults(suiteName: suiteName)!
    clearDefaults()
  }

  override func tearDown() async throws {
    clearDefaults()
    defaults = nil
    try await super.tearDown()
  }

  private func clearDefaults() {
    for key in defaults.dictionaryRepresentation().keys {
      defaults.removeObject(forKey: key)
    }
  }

  func testTodayCountStartsAtZero() {
    let store = PrepQuizLimitStore(defaults: defaults)
    let user = UUID()
    XCTAssertEqual(store.todayCount(for: user, now: fixedNow), 0)
  }

  func testRemainingAndCanStart() {
    let store = PrepQuizLimitStore(defaults: defaults)
    let user = UUID()
    XCTAssertEqual(store.remaining(for: user, maxPerDay: 5, now: fixedNow), 5)
    XCTAssertTrue(store.canStart(for: user, maxPerDay: 5, now: fixedNow))
  }

  func testIncrementIfAllowedStopsAtMax() {
    let store = PrepQuizLimitStore(defaults: defaults)
    let user = UUID()
    for i in 1...5 {
      XCTAssertTrue(store.incrementIfAllowed(for: user, maxPerDay: 5, now: fixedNow), "iteration \(i)")
    }
    XCTAssertFalse(store.incrementIfAllowed(for: user, maxPerDay: 5, now: fixedNow))
    XCTAssertEqual(store.todayCount(for: user, now: fixedNow), 5)
    XCTAssertEqual(store.remaining(for: user, maxPerDay: 5, now: fixedNow), 0)
    XCTAssertFalse(store.canStart(for: user, maxPerDay: 5, now: fixedNow))
  }

  func testCustomMaxPerDay() {
    let store = PrepQuizLimitStore(defaults: defaults)
    let user = UUID()
    XCTAssertTrue(store.incrementIfAllowed(for: user, maxPerDay: 2, now: fixedNow))
    XCTAssertTrue(store.incrementIfAllowed(for: user, maxPerDay: 2, now: fixedNow))
    XCTAssertFalse(store.incrementIfAllowed(for: user, maxPerDay: 2, now: fixedNow))
    XCTAssertEqual(store.todayCount(for: user, now: fixedNow), 2)
  }
}
