// BattleRealtimeSubscriber.swift
// 封裝戰鬥房 Supabase Realtime 訂閱：監聽 battle_cells 變更，每次事件呼叫 onChange 回呼。
// 由 StrategicBattleViewModel 持有；view 的 .task / .onDisappear 控制生命週期。

import Foundation
import os
import Supabase

@MainActor
final class BattleRealtimeSubscriber {
  private let roomId: UUID
  private let authService: AuthService
  private var channel: RealtimeChannelV2?

  /// view 可據此決定是否跳過手動 foreground polling。
  private(set) var isActive = false

  init(roomId: UUID, authService: AuthService) {
    self.roomId = roomId
    self.authService = authService
  }

  /// 訂閱 battle_cells 變更。事件流啟動後阻塞於 for-await，直到 Task 被取消（例如 view 消失）。
  /// - Parameter onChange: 每次收到變更通知時呼叫；由呼叫端決定如何刷新 UI 狀態。
  func subscribe(onChange: @escaping () async -> Void) async {
    let client = authService.getClient()
    let channel = client.realtimeV2.channel("battle-cells-\(roomId.uuidString)")
    self.channel = channel

    defer {
      isActive = false
      self.channel = nil
      let ch = channel
      Task { await ch.unsubscribe() }
    }

    let changeStream = channel.postgresChange(
      AnyAction.self,
      schema: "public",
      table: "battle_cells",
      filter: .eq("room_id", value: roomId.uuidString)
    )

    do {
      try await channel.subscribeWithError()
    } catch {
      #if DEBUG
      AppLog.battle.info("[Battle] Realtime subscribe failed: \(error)")
      #endif
      return
    }
    isActive = true

    #if DEBUG
    AppLog.battle.info("[Battle] Realtime subscribed to battle_cells for room \(self.roomId)")
    #endif

    for await _ in changeStream {
      guard !Task.isCancelled else { break }
      #if DEBUG
      AppLog.battle.info("[Battle] Realtime: battle_cells changed, refreshing board")
      #endif
      await onChange()
    }
  }

  /// view onDisappear 時呼叫，確保 channel 立即釋放。
  func unsubscribe() {
    isActive = false
    guard let channel = channel else { return }
    self.channel = nil
    Task { await channel.unsubscribe() }
  }
}
