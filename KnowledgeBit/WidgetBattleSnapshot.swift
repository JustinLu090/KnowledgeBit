// WidgetBattleSnapshot.swift
// 將對戰地圖快照寫入 App Group，供 BattleMapWidget 讀取

import Foundation
import WidgetKit

/// 單格快照，與 Widget 端 JSON 格式一致
struct WidgetBattleCellSnapshot: Codable {
  let id: Int
  let owner: String // "player" | "enemy" | "neutral"
  let hp_now: Int
  let hp_max: Int
}

enum WidgetBattleSnapshot {
  static let battleMapWidgetKind = "BattleMapWidget"

  /// 寫入對戰地圖快照到 App Group 並重新載入 BattleMapWidget timeline
  static func save(
    roomId: UUID,
    wordSetId: UUID,
    wordSetTitle: String?,
    creatorId: UUID?,
    currentUserId: UUID?,
    cells: [WidgetBattleCellSnapshot]
  ) {
    guard cells.count == 16,
          let defaults = AppGroup.sharedUserDefaults() else { return }

    defaults.set(wordSetId.uuidString, forKey: AppGroup.Keys.widgetBattleWordSetId)
    defaults.set(roomId.uuidString, forKey: AppGroup.Keys.widgetBattleRoomId)
    defaults.set(wordSetTitle ?? "", forKey: AppGroup.Keys.widgetBattleWordSetTitle)
    defaults.set(creatorId?.uuidString ?? "", forKey: AppGroup.Keys.widgetBattleCreatorId)
    defaults.set(currentUserId?.uuidString ?? "", forKey: AppGroup.Keys.widgetBattleCurrentUserId)
    defaults.set(Date().timeIntervalSince1970, forKey: AppGroup.Keys.widgetBattleUpdatedAt)

    if let data = try? JSONEncoder().encode(cells),
       let json = String(data: data, encoding: .utf8) {
      defaults.set(json, forKey: AppGroup.Keys.widgetBattleCells)
    }
    defaults.synchronize()

    WidgetCenter.shared.reloadTimelines(ofKind: battleMapWidgetKind)
  }
}
