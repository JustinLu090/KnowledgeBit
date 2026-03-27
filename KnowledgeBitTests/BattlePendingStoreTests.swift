import XCTest
@testable import KnowledgeBit

@MainActor
final class BattlePendingStoreTests: XCTestCase {

  private var defaults: UserDefaults!
  private let suiteName = "com.knowledgebit.tests.BattlePendingStore"

  private let roomId = UUID()
  private let hourBucket = Date(timeIntervalSince1970: 1_730_000_000)

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

  func testSaveLoadAllocationsRoundTrip() {
    let store = BattlePendingStore(defaults: defaults)
    let allocations: [Int: Int] = [0: 3, 1: 5, 10: 1]
    store.save(roomId: roomId, hourBucket: hourBucket, allocations: allocations)
    XCTAssertEqual(store.load(roomId: roomId, hourBucket: hourBucket), allocations)
  }

  func testSaveEmptyRemoves() {
    let store = BattlePendingStore(defaults: defaults)
    store.save(roomId: roomId, hourBucket: hourBucket, allocations: [1: 1])
    store.save(roomId: roomId, hourBucket: hourBucket, allocations: [:])
    XCTAssertNil(store.load(roomId: roomId, hourBucket: hourBucket))
  }

  func testFailedSubmissionsRoundTrip() {
    let store = BattlePendingStore(defaults: defaults)
    let d1 = Date(timeIntervalSince1970: 1_731_000_000)
    let d2 = Date(timeIntervalSince1970: 1_731_100_000)
    let submissions: [Date: [Int: Int]] = [
      d1: [0: 2, 3: 4],
      d2: [1: 1]
    ]
    store.saveFailedSubmissions(roomId: roomId, submissions: submissions)
    let loaded = store.loadFailedSubmissions(roomId: roomId)
    XCTAssertEqual(loaded.count, 2)
    let byTs = Dictionary(uniqueKeysWithValues: loaded.map { (Int($0.key.timeIntervalSince1970), $0.value) })
    XCTAssertEqual(byTs[1_731_000_000], [0: 2, 3: 4])
    XCTAssertEqual(byTs[1_731_100_000], [1: 1])
    store.clearFailedSubmissions(roomId: roomId)
    XCTAssertTrue(store.loadFailedSubmissions(roomId: roomId).isEmpty)
  }
}
