// BattleSessionStore.swift
// 對戰場次（房間）本地持久化：以 App Group UserDefaults 依單字集保存

import Foundation

struct BattleSession: Codable, Equatable {
  let wordSetID: UUID
  let startDate: Date
  let durationDays: Int
  let invitedMemberIDs: [UUID]

  var endDate: Date { startDate.addingTimeInterval(TimeInterval(durationDays) * 24 * 3600) }
  var battleStartDate: Date { startDate.addingTimeInterval(TimeInterval(durationDays) * 24 * 3600 * 0.75) }

  func isActive(at date: Date = Date()) -> Bool {
    date < endDate
  }
}

@MainActor
final class BattleSessionStore {
  private let defaults = AppGroup.sharedUserDefaults()
  private let baseKey = "battle_session"

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
