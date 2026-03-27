import XCTest
@testable import KnowledgeBit

final class BattleSessionModelTests: XCTestCase {

  func testEndDateIsStartPlusDurationDays() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let ws = UUID()
    let room = UUID()
    let session = BattleSession(
      roomId: room,
      wordSetID: ws,
      startDate: start,
      durationDays: 7,
      invitedMemberIDs: []
    )
    let expectedEnd = start.addingTimeInterval(7 * 24 * 3600)
    XCTAssertEqual(session.endDate.timeIntervalSince1970, expectedEnd.timeIntervalSince1970, accuracy: 0.001)
  }

  func testBattleStartDateIsThreeQuartersThroughDuration() {
    let start = Date(timeIntervalSince1970: 2_000_000)
    let session = BattleSession(
      roomId: UUID(),
      wordSetID: UUID(),
      startDate: start,
      durationDays: 4,
      invitedMemberIDs: [],
      creatorId: UUID()
    )
    let quarter = TimeInterval(4) * 24 * 3600 * 0.25
    let expectedBattleStart = start.addingTimeInterval(TimeInterval(4) * 24 * 3600 * 0.75)
    XCTAssertEqual(session.battleStartDate.timeIntervalSince1970, expectedBattleStart.timeIntervalSince1970, accuracy: 0.001)
    XCTAssertEqual(session.endDate.timeIntervalSince(session.battleStartDate), quarter, accuracy: 0.001)
  }

  func testIsActiveBeforeEndDate() {
    let start = Date(timeIntervalSince1970: 5_000_000)
    let session = BattleSession(
      roomId: UUID(),
      wordSetID: UUID(),
      startDate: start,
      durationDays: 1,
      invitedMemberIDs: []
    )
    let mid = start.addingTimeInterval(12 * 3600)
    XCTAssertTrue(session.isActive(at: mid))
    XCTAssertFalse(session.isActive(at: session.endDate))
    XCTAssertFalse(session.isActive(at: session.endDate.addingTimeInterval(1)))
  }

  func testCodableRoundTrip() throws {
    let room = UUID()
    let ws = UUID()
    let creator = UUID()
    let invited = [UUID(), UUID()]
    let start = Date(timeIntervalSince1970: 9_000_000)
    let original = BattleSession(
      roomId: room,
      wordSetID: ws,
      startDate: start,
      durationDays: 14,
      invitedMemberIDs: invited,
      creatorId: creator
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(BattleSession.self, from: data)
    XCTAssertEqual(decoded, original)
  }
}
