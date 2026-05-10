import XCTest
@testable import KnowledgeBit

@MainActor
final class FailedSubmissionQueueTests: XCTestCase {

  private var defaults: UserDefaults!
  private let suiteName = "com.knowledgebit.tests.FailedSubmissionQueue"
  private let roomId = UUID()

  private let bucketA = Date(timeIntervalSince1970: 1_730_000_000)
  private let bucketB = Date(timeIntervalSince1970: 1_730_003_600)
  private let bucketC = Date(timeIntervalSince1970: 1_730_007_200)

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

  private func makeQueue() -> FailedSubmissionQueue {
    let store = BattlePendingStore(defaults: defaults)
    return FailedSubmissionQueue(roomId: roomId, store: store)
  }

  // MARK: - In-flight bookkeeping

  func testTryBeginFlightFirstCallSucceeds() {
    let queue = makeQueue()
    XCTAssertTrue(queue.tryBeginFlight(bucket: bucketA))
    XCTAssertTrue(queue.isInFlight(bucket: bucketA))
  }

  func testTryBeginFlightSecondCallFailsForSameBucket() {
    let queue = makeQueue()
    XCTAssertTrue(queue.tryBeginFlight(bucket: bucketA))
    // 雙觸發保護：同 bucket 第二次必須回 false
    XCTAssertFalse(queue.tryBeginFlight(bucket: bucketA))
  }

  func testEndFlightAllowsSubsequentBeginFlight() {
    let queue = makeQueue()
    _ = queue.tryBeginFlight(bucket: bucketA)
    queue.endFlight(bucket: bucketA)
    XCTAssertFalse(queue.isInFlight(bucket: bucketA))
    XCTAssertTrue(queue.tryBeginFlight(bucket: bucketA))
  }

  func testInFlightTrackingIndependentPerBucket() {
    let queue = makeQueue()
    XCTAssertTrue(queue.tryBeginFlight(bucket: bucketA))
    // 不同 bucket 不互相影響
    XCTAssertTrue(queue.tryBeginFlight(bucket: bucketB))
    XCTAssertTrue(queue.isInFlight(bucket: bucketA))
    XCTAssertTrue(queue.isInFlight(bucket: bucketB))
  }

  // MARK: - Record / Retrieve

  func testRecordAndAllocations() {
    let queue = makeQueue()
    let allocations: [Int: Int] = [3: 100, 5: 50]
    queue.record(bucket: bucketA, allocations: allocations)
    XCTAssertEqual(queue.allocations(for: bucketA), allocations)
  }

  func testAllocationsForUnknownBucketReturnsNil() {
    let queue = makeQueue()
    XCTAssertNil(queue.allocations(for: bucketA))
  }

  func testRemoveDeletesAllocations() {
    let queue = makeQueue()
    queue.record(bucket: bucketA, allocations: [1: 10])
    queue.remove(bucket: bucketA)
    XCTAssertNil(queue.allocations(for: bucketA))
  }

  // MARK: - sortedBuckets

  func testSortedBucketsReturnsChronologicalOrder() {
    let queue = makeQueue()
    queue.record(bucket: bucketC, allocations: [0: 1])
    queue.record(bucket: bucketA, allocations: [0: 1])
    queue.record(bucket: bucketB, allocations: [0: 1])
    XCTAssertEqual(queue.sortedBuckets(), [bucketA, bucketB, bucketC])
  }

  func testSortedBucketsEmptyWhenNothingRecorded() {
    let queue = makeQueue()
    XCTAssertTrue(queue.sortedBuckets().isEmpty)
  }

  // MARK: - Persistence

  func testRecordAutoPersistsToStore() {
    let queue = makeQueue()
    queue.record(bucket: bucketA, allocations: [2: 25])

    // 重新建一個 queue 後 restore：應能讀回
    let queue2 = makeQueue()
    queue2.restore()
    XCTAssertEqual(queue2.allocations(for: bucketA), [2: 25])
  }

  func testRemoveAlonePersistsAfterCallingPersist() {
    let queue = makeQueue()
    queue.record(bucket: bucketA, allocations: [1: 10])
    queue.record(bucket: bucketB, allocations: [2: 20])
    queue.remove(bucket: bucketA)
    queue.persist()  // 模擬批次 retry 結束的呼叫

    let queue2 = makeQueue()
    queue2.restore()
    XCTAssertNil(queue2.allocations(for: bucketA))
    XCTAssertEqual(queue2.allocations(for: bucketB), [2: 20])
  }

  func testRestoreOnEmptyStoreLeavesQueueEmpty() {
    let queue = makeQueue()
    queue.restore()
    XCTAssertTrue(queue.sortedBuckets().isEmpty)
  }
}
