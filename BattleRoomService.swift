// BattleRoomService.swift
// 對戰房間服務：提交本小時投入、讀取雲端彙整後的盤面

import Foundation
import Supabase

struct BoardCellDTO: Decodable {
  let id: Int
  let owner: String // "neutral" | "player" | "enemy"
  let hp_now: Int
  let hp_max: Int
  let decay_per_hour: Int
  let enemy_pressure: Int
}

@MainActor
final class BattleRoomService {
  private let client: SupabaseClient
  private let userId: UUID

  init(authService: AuthService, userId: UUID) {
    self.client = authService.getClient()
    self.userId = userId
  }

  /// 將本小時投入提交至雲端（原子 upsert）。
  /// 伺服器端會在整點後彙整所有玩家投入並產生盤面。
  func submitAllocations(roomId: UUID, hourBucket: Date, allocations: [Int: Int]) async throws {
    // 以簡單 RPC 傳送：room_id、hour_bucket（ISO8601）、user_id、allocations(JSON)
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    let hourString = iso.string(from: hourBucket)

    // 將字典 key 轉為字串，避免編碼問題
    let strDict = Dictionary(uniqueKeysWithValues: allocations.map { ("\($0.key)", $0.value) })

    _ = try await client
      .rpc("submit_battle_allocations", params: [
        "p_room_id": roomId.uuidString,
        "p_hour_bucket": hourString,
        "p_user_id": userId.uuidString,
        "p_allocations": strDict
      ])
      .execute()
  }

  /// 取得指定小時的盤面（若伺服器端尚未彙整完成，可重試）。
  func fetchBoardState(roomId: UUID, hourBucket: Date) async throws -> [BoardCellDTO] {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    let hourString = iso.string(from: hourBucket)

    struct Row: Decodable { let cells: [BoardCellDTO] }
    let rows: [Row] = try await client
      .rpc("get_battle_board_state", params: [
        "p_room_id": roomId.uuidString,
        "p_hour_bucket": hourString
      ])
      .execute()
      .value
    return rows.first?.cells ?? []
  }
}
