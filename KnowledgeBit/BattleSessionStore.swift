// BattleSessionStore.swift
// 對戰場次（房間）本地持久化：以 App Group UserDefaults 依單字集保存

import Foundation

struct BattleSession: Codable, Equatable {
  let roomId: UUID
  let wordSetID: UUID
  let startDate: Date
  let durationDays: Int
  let invitedMemberIDs: [UUID]
  /// 創辦人 user id（發起戰鬥者）= 藍隊；被邀請成員 = 紅隊
  let creatorId: UUID?

  init(roomId: UUID, wordSetID: UUID, startDate: Date, durationDays: Int, invitedMemberIDs: [UUID], creatorId: UUID? = nil) {
    self.roomId = roomId
    self.wordSetID = wordSetID
    self.startDate = startDate
    self.durationDays = durationDays
    self.invitedMemberIDs = invitedMemberIDs
    self.creatorId = creatorId
  }

  var endDate: Date { startDate.addingTimeInterval(TimeInterval(durationDays) * 24 * 3600) }
  var battleStartDate: Date { startDate.addingTimeInterval(TimeInterval(durationDays) * 24 * 3600 * 0.75) }

  func isActive(at date: Date = Date()) -> Bool {
    date < endDate
  }
}

@MainActor
final class BattleSessionStore {
  private let defaults: UserDefaults?
  private let baseKey = "battle_session"

  /// - Note: 預設參數不可為 `AppGroup.sharedUserDefaults()`（Swift 6 會在 nonisolated 脈絡求值而報錯）。
  init(defaults: UserDefaults? = nil) {
    self.defaults = defaults ?? UserDefaults(suiteName: AppGroup.identifier)
  }

  private func key(for wordSetID: UUID) -> String { "\(baseKey).\(wordSetID.uuidString)" }

  func save(_ session: BattleSession) {
    guard let data = try? JSONEncoder().encode(session) else { return }
    defaults?.set(data, forKey: key(for: session.wordSetID))
    defaults?.synchronize()
  }

  func load(for wordSetID: UUID) -> BattleSession? {
    guard let data = defaults?.data(forKey: key(for: wordSetID)) else { return nil }
    return try? JSONDecoder().decode(BattleSession.self, from: data)
  }

  func isActive(for wordSetID: UUID, at date: Date = Date()) -> Bool {
    guard let session = load(for: wordSetID) else { return false }
    return session.isActive(at: date)
  }

  func clear(for wordSetID: UUID) {
    defaults?.removeObject(forKey: key(for: wordSetID))
    defaults?.synchronize()
  }
}

// MARK: - 本小時 KE 分配暫存（離開再進入仍可看到並修改，直到整點前 2 分鐘鎖定）

/// 依房間 + 小時儲存「本小時尚未結算」的 KE 分配，下次點開可還原並繼續修改
@MainActor
final class BattlePendingStore {
  private let defaults: UserDefaults?
  private let baseKey = "battle_pending"

  /// - Note: 預設參數不可為 `AppGroup.sharedUserDefaults()`（Swift 6 會在 nonisolated 脈絡求值而報錯）。
  init(defaults: UserDefaults? = nil) {
    self.defaults = defaults ?? UserDefaults(suiteName: AppGroup.identifier)
  }

  private func key(roomId: UUID, hourBucket: Date) -> String {
    let ts = Int(hourBucket.timeIntervalSince1970)
    return "\(baseKey).\(roomId.uuidString).\(ts)"
  }

  func save(roomId: UUID, hourBucket: Date, allocations: [Int: Int]) {
    guard !allocations.isEmpty else {
      remove(roomId: roomId, hourBucket: hourBucket)
      return
    }
    let dict = Dictionary(uniqueKeysWithValues: allocations.map { ("\($0.key)", $0.value) })
    guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
    defaults?.set(data, forKey: key(roomId: roomId, hourBucket: hourBucket))
    defaults?.synchronize()
  }

  func load(roomId: UUID, hourBucket: Date) -> [Int: Int]? {
    guard let data = defaults?.data(forKey: key(roomId: roomId, hourBucket: hourBucket)),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else { return nil }
    return Dictionary(uniqueKeysWithValues: dict.compactMap { key, value in Int(key).map { ($0, value) } })
  }

  func remove(roomId: UUID, hourBucket: Date) {
    defaults?.removeObject(forKey: key(roomId: roomId, hourBucket: hourBucket))
    defaults?.synchronize()
  }

  // MARK: - Failed Submission Persistence
  // Stores the queue of buckets that failed to submit so it survives app restarts.
  // Format: "battle_pending_failed.{roomId}" -> JSON { "{timestamp}": { "cellId": ke, ... } }

  private func failedKey(roomId: UUID) -> String {
    "\(baseKey)_failed.\(roomId.uuidString)"
  }

  func saveFailedSubmissions(roomId: UUID, submissions: [Date: [Int: Int]]) {
    guard !submissions.isEmpty else {
      defaults?.removeObject(forKey: failedKey(roomId: roomId))
      defaults?.synchronize()
      return
    }
    // Serialise as { "<timestampInt>": { "<cellId>": ke } }
    let serialisable = Dictionary(uniqueKeysWithValues: submissions.map { date, allocs -> (String, [String: Int]) in
      let tsKey = String(Int(date.timeIntervalSince1970))
      let strAllocs = Dictionary(uniqueKeysWithValues: allocs.map { ("\($0.key)", $0.value) })
      return (tsKey, strAllocs)
    })
    guard let data = try? JSONSerialization.data(withJSONObject: serialisable) else { return }
    defaults?.set(data, forKey: failedKey(roomId: roomId))
    defaults?.synchronize()
  }

  func loadFailedSubmissions(roomId: UUID) -> [Date: [Int: Int]] {
    guard let data = defaults?.data(forKey: failedKey(roomId: roomId)),
          let outer = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Int]]
    else { return [:] }
    return Dictionary(uniqueKeysWithValues: outer.compactMap { tsKey, strAllocs -> (Date, [Int: Int])? in
      guard let ts = TimeInterval(tsKey) else { return nil }
      let allocs = Dictionary(uniqueKeysWithValues: strAllocs.compactMap { k, v in Int(k).map { ($0, v) } })
      return (Date(timeIntervalSince1970: ts), allocs)
    })
  }

  func clearFailedSubmissions(roomId: UUID) {
    defaults?.removeObject(forKey: failedKey(roomId: roomId))
    defaults?.synchronize()
  }
}
