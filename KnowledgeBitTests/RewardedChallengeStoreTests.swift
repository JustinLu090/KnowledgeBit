import XCTest
@testable import KnowledgeBit

@MainActor
final class RewardedChallengeStoreTests: XCTestCase {

  private var defaults: UserDefaults!
  private let suiteName = "com.knowledgebit.tests.RewardedChallengeStore"
  private let key = "test_rewarded_ids"

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

  private func makeStore(capacity: Int = 200) -> RewardedChallengeStore {
    RewardedChallengeStore(defaults: defaults, key: key, capacity: capacity)
  }

  // MARK: - Basic semantics

  func testInitialStateIsEmpty() {
    let store = makeStore()
    XCTAssertEqual(store.count, 0)
    XCTAssertFalse(store.contains(UUID()))
  }

  func testRecordAddsId() {
    let store = makeStore()
    let id = UUID()
    XCTAssertTrue(store.record(id))
    XCTAssertTrue(store.contains(id))
    XCTAssertEqual(store.count, 1)
  }

  func testRecordReturnsFalseForDuplicate() {
    let store = makeStore()
    let id = UUID()
    XCTAssertTrue(store.record(id))
    // 重複加入應回傳 false 且不影響 count
    XCTAssertFalse(store.record(id))
    XCTAssertEqual(store.count, 1)
  }

  // MARK: - Persistence

  func testPersistsAcrossInstances() {
    let id = UUID()
    let store1 = makeStore()
    store1.record(id)

    // 建立新 instance（模擬 app 重啟）
    let store2 = makeStore()
    XCTAssertTrue(store2.contains(id))
  }

  // MARK: - FIFO capacity

  func testFIFOEvictsOldestWhenOverCapacity() {
    let store = makeStore(capacity: 3)
    let ids = (0..<5).map { _ in UUID() }
    for id in ids { store.record(id) }

    // 容量 3，記錄 5 個，預期淘汰最早 2 個
    XCTAssertEqual(store.count, 3)
    XCTAssertFalse(store.contains(ids[0]))
    XCTAssertFalse(store.contains(ids[1]))
    XCTAssertTrue(store.contains(ids[2]))
    XCTAssertTrue(store.contains(ids[3]))
    XCTAssertTrue(store.contains(ids[4]))
  }

  func testCapacityOneKeepsOnlyLatest() {
    let store = makeStore(capacity: 1)
    let first = UUID()
    let second = UUID()
    store.record(first)
    store.record(second)
    XCTAssertFalse(store.contains(first))
    XCTAssertTrue(store.contains(second))
    XCTAssertEqual(store.count, 1)
  }

  // MARK: - Clear

  func testClearRemovesAll() {
    let store = makeStore()
    store.record(UUID())
    store.record(UUID())
    store.clear()
    XCTAssertEqual(store.count, 0)
  }
}
