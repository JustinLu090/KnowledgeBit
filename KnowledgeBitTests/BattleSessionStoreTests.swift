import XCTest
@testable import KnowledgeBit

@MainActor
final class BattleSessionStoreTests: XCTestCase {

  private var defaults: UserDefaults!
  private let suiteName = "com.knowledgebit.tests.BattleSessionStore"

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

  func testSaveLoadRoundTrip() {
    let store = BattleSessionStore(defaults: defaults)
    let wordSetID = UUID()
    let roomId = UUID()
    let start = Date(timeIntervalSince1970: 1_800_000)
    let session = BattleSession(
      roomId: roomId,
      wordSetID: wordSetID,
      startDate: start,
      durationDays: 3,
      invitedMemberIDs: [UUID()],
      creatorId: UUID()
    )
    store.save(session)
    XCTAssertEqual(store.load(for: wordSetID), session)
  }

  func testLoadMissingReturnsNil() {
    let store = BattleSessionStore(defaults: defaults)
    XCTAssertNil(store.load(for: UUID()))
  }

  func testClearRemovesSession() {
    let store = BattleSessionStore(defaults: defaults)
    let ws = UUID()
    let session = BattleSession(
      roomId: UUID(),
      wordSetID: ws,
      startDate: Date(),
      durationDays: 1,
      invitedMemberIDs: []
    )
    store.save(session)
    store.clear(for: ws)
    XCTAssertNil(store.load(for: ws))
  }

  func testIsActiveDelegatesToLoadedSession() {
    let store = BattleSessionStore(defaults: defaults)
    let ws = UUID()
    let start = Date(timeIntervalSince1970: 2_000_000)
    let session = BattleSession(
      roomId: UUID(),
      wordSetID: ws,
      startDate: start,
      durationDays: 1,
      invitedMemberIDs: []
    )
    store.save(session)
    let beforeEnd = start.addingTimeInterval(100)
    XCTAssertTrue(store.isActive(for: ws, at: beforeEnd))
    XCTAssertFalse(store.isActive(for: ws, at: session.endDate))
    XCTAssertFalse(store.isActive(for: UUID(), at: beforeEnd))
  }
}
