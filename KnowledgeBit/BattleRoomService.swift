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

/// 上一輪結算的雙方投入統整：藍隊／紅隊在各格投入的 KE
struct BattleRoundSummary {
  /// 藍隊（創辦人）在各格投入的 KE：cellIndex (0..<16) -> KE
  let blueAllocations: [Int: Int]
  /// 紅隊（被邀請）在各格投入的 KE
  let redAllocations: [Int: Int]
}

/// 後端 JSONB 可能回傳數字為 Int 或 Double，需相容解碼
private func parseAllocations(_ dict: [String: Int]?) -> [Int: Int] {
  guard let dict = dict else { return [:] }
  return dict.reduce(into: [:]) { acc, kv in
    if let i = Int(kv.key), i >= 0, i < 16 { acc[i] = kv.value }
  }
}


@MainActor
final class BattleRoomService {
  private let client: SupabaseClient
  private let userId: UUID

  init(authService: AuthService, userId: UUID) {
    self.client = authService.getClient()
    self.userId = userId
  }

  struct ActiveRoomDTO: Decodable {
    let id: UUID
    let word_set_id: UUID
    let creator_id: UUID
    let start_date: Date
    let duration_days: Int
    let invited_member_ids: [UUID]
  }

  /// 建立對戰房間，回傳 room_id。
  func createRoom(wordSetID: UUID, startDate: Date, durationDays: Int, invitedMemberIDs: [UUID]) async throws -> UUID {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    let startString = iso.string(from: startDate)
    let invitedStrings = invitedMemberIDs.map(\.uuidString)
    let invitedJSON = (try? JSONEncoder().encode(invitedStrings)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    let raw: String = try await client
      .rpc("create_battle_room", params: [
        "p_word_set_id": wordSetID.uuidString,
        "p_creator_id": userId.uuidString,
        "p_start_date": startString,
        "p_duration_days": String(durationDays),
        "p_invited_ids": invitedJSON
      ])
      .execute()
      .value
    guard let roomId = UUID(uuidString: raw) else {
      throw NSError(domain: "BattleRoomService", code: -1, userInfo: [NSLocalizedDescriptionKey: "create_battle_room returned invalid room_id"])
    }
    return roomId
  }

  /// 將本小時投入提交至雲端（原子 upsert）。網路不穩時會自動重試最多 3 次（間隔 2 秒）。
  /// 伺服器端會在整點後彙整所有玩家投入並產生盤面。
  func submitAllocations(roomId: UUID, hourBucket: Date, allocations: [Int: Int], bucketSeconds: Int = 3600) async throws {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    let hourString = iso.string(from: hourBucket)

    let strDict = Dictionary(uniqueKeysWithValues: allocations.map { ("\($0.key)", $0.value) })
    let allocationsJSON = (try? JSONSerialization.data(withJSONObject: strDict))
      .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

    let params: [String: String] = [
      "p_room_id": roomId.uuidString,
      "p_hour_bucket": hourString,
      "p_user_id": userId.uuidString,
      "p_allocations": allocationsJSON,
      "p_bucket_seconds": String(max(60, bucketSeconds))
    ]

    let maxAttempts = 3
    let retryDelay: UInt64 = 2_000_000_000
    var lastError: Error?

    for attempt in 1...maxAttempts {
      do {
        #if DEBUG
        if attempt > 1 {
          print("[Battle] submit_battle_allocations retry \(attempt)/\(maxAttempts)")
        } else {
          print("[Battle] RPC submit_battle_allocations room=\(roomId) bucket=\(hourString) bucketSeconds=\(bucketSeconds) allocations=", strDict)
        }
        #endif
        _ = try await client.rpc("submit_battle_allocations", params: params).execute()
        return
      } catch {
        lastError = error
        let isRetryable: Bool = {
          if let e = error as? URLError {
            switch e.code {
            case .networkConnectionLost, .timedOut, .notConnectedToInternet:
              return true
            default: return false
            }
          }
          return false
        }()
        if isRetryable, attempt < maxAttempts {
          try? await Task.sleep(nanoseconds: retryDelay)
          continue
        }
        throw error
      }
    }
    if let e = lastError { throw e }
  }

  /// 取得指定小時（上一輪）的雙方投入統整，供 UI 顯示「藍隊／紅隊在各格做了什麼」
  /// 後端 JSONB 數字可能為 Int 或 Double，先以 Data 取回再手動解析
  func fetchRoundSummary(roomId: UUID, hourBucket: Date, bucketSeconds: Int = 3600) async throws -> BattleRoundSummary {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    let hourString = iso.string(from: hourBucket)

    struct Row: Decodable {
      let blue_allocations: AnyCodableDict?
      let red_allocations: AnyCodableDict?
    }
    struct AnyCodableDict: Decodable {
      let dict: [String: Int]
      init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode([String: Int].self) { dict = d; return }
        if let d = try? container.decode([String: Double].self) {
          dict = d.mapValues { Int($0.rounded()) }
          return
        }
        // 部分客戶端會把 JSONB 回傳成字串
        if let raw = try? container.decode(String.self),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
          dict = decoded
          return
        }
        if let raw = try? container.decode(String.self),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
          dict = decoded.mapValues { Int($0.rounded()) }
          return
        }
        dict = [:]
      }
    }
    let rows: [Row] = try await client
      .rpc("get_battle_round_summary", params: [
        "p_room_id": roomId.uuidString,
        "p_hour_bucket": hourString,
        "p_bucket_seconds": String(max(60, bucketSeconds))
      ])
      .execute()
      .value
    guard let row = rows.first else {
      return BattleRoundSummary(blueAllocations: [:], redAllocations: [:])
    }
    let blue = row.blue_allocations.map { parseAllocations($0.dict) } ?? [:]
    let red = row.red_allocations.map { parseAllocations($0.dict) } ?? [:]
    #if DEBUG
    if !blue.isEmpty || !red.isEmpty {
      print("[Battle] fetchRoundSummary blue=\(blue) red=\(red)")
    }
    #endif
    return BattleRoundSummary(blueAllocations: blue, redAllocations: red)
  }

  /// 取得指定小時的盤面（若伺服器端尚未彙整完成，可重試）。
  func fetchBoardState(roomId: UUID, hourBucket: Date, bucketSeconds: Int = 3600) async throws -> [BoardCellDTO] {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    let hourString = iso.string(from: hourBucket)

    struct Row: Decodable { let cells: [BoardCellDTO] }
    #if DEBUG
    print("[Battle] RPC get_battle_board_state room=\(roomId) bucket=\(hourString) bucketSeconds=\(bucketSeconds)")
    #endif

    let rows: [Row] = try await client
      .rpc("get_battle_board_state", params: [
        "p_room_id": roomId.uuidString,
        "p_hour_bucket": hourString,
        "p_bucket_seconds": String(max(60, bucketSeconds))
      ])
      .execute()
      .value
    return rows.first?.cells ?? []
  }

  /// 取得目前使用者在某單字集底下的「進行中」對戰房間（若有的話）
  func fetchActiveRoom(wordSetID: UUID) async throws -> BattleSession? {
    let rooms: [ActiveRoomDTO] = try await client
      .rpc("get_active_battle_room_for_user", params: [
        "p_word_set_id": wordSetID.uuidString
      ])
      .execute()
      .value

    guard let dto = rooms.first else { return nil }
    return BattleSession(
      roomId: dto.id,
      wordSetID: dto.word_set_id,
      startDate: dto.start_date,
      durationDays: dto.duration_days,
      invitedMemberIDs: dto.invited_member_ids,
      creatorId: dto.creator_id
    )
  }
}
