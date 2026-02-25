// BattleEnergyService.swift
// 雲端 KE 服務：透過 Supabase RPC 執行原子加減與查詢

import Foundation
import Supabase

@MainActor
final class BattleEnergyService {
  private let client: SupabaseClient
  private let userId: UUID

  init(authService: AuthService, userId: UUID) {
    self.client = authService.getClient()
    self.userId = userId
  }

  /// 讀取目前雲端 KE 值（若無記錄則視為 0）
  func fetchKE(namespace: String) async throws -> Int {
    struct Row: Decodable { let available_ke: Int }
    // 直接查表（需先依 README 建立 battle_energy 表與 RLS）
    let rows: [Row] = try await client
      .from("battle_energy")
      .select("available_ke")
      .eq("user_id", value: userId)
      .eq("namespace", value: namespace)
      .limit(1)
      .execute()
      .value
    return rows.first?.available_ke ?? 0
  }

  /// 原子增加 KE（正數）
  func incrementKE(namespace: String, delta: Int) async {
    guard delta > 0 else { return }
    do {
      _ = try await client
        .rpc("ke_increment", params: [
          "p_user_id": userId.uuidString,
          "p_namespace": namespace,
          "p_delta": delta
        ])
        .execute()
    } catch {
      print("⚠️ [KE] increment RPC 失敗: \(error)")
    }
  }

  /// 原子扣除 KE（若不足應由 RPC 拒絕，確保不會變負）
  func spendKE(namespace: String, amount: Int) async {
    guard amount > 0 else { return }
    do {
      _ = try await client
        .rpc("ke_spend", params: [
          "p_user_id": userId.uuidString,
          "p_namespace": namespace,
          "p_amount": amount
        ])
        .execute()
    } catch {
      print("⚠️ [KE] spend RPC 失敗: \(error)")
    }
  }

  /// 直接設值（upsert），用於 reset 或矯正
  func setKE(namespace: String, value: Int) async {
    struct Payload: Encodable {
      let user_id: UUID
      let namespace: String
      let available_ke: Int
    }
    let payload = Payload(user_id: userId, namespace: namespace, available_ke: max(0, value))
    do {
      try await client.from("battle_energy")
        .upsert(payload, onConflict: "user_id,namespace")
        .execute()
    } catch {
      print("⚠️ [KE] set upsert 失敗: \(error)")
    }
  }
}
