// PendingBattleOpenStore.swift
// 由 knowledgebit://battle?wordSetId= 深連結設定，供 MainTabView / LibraryView 導航至該單字集

import Combine
import Foundation

@MainActor
final class PendingBattleOpenStore: ObservableObject {
  enum PendingOpenKind {
    case wordSet
    case battle
  }

  @Published var wordSetIdToOpen: UUID?
  @Published var openKind: PendingOpenKind?
  /// 用於從「測驗結算」直接切到攻佔地圖：告訴 `BattleRoomView` 需要導到 `StrategicBattleView`。
  @Published var battleRoomIdToOpenForMap: UUID?

  func setWordSetIdToOpen(_ id: UUID?) {
    wordSetIdToOpen = id
    openKind = id == nil ? nil : .wordSet
  }

  func setBattleWordSetIdToOpen(_ id: UUID?) {
    wordSetIdToOpen = id
    openKind = id == nil ? nil : .battle
  }

  func clearWordSetIdToOpen() {
    wordSetIdToOpen = nil
    openKind = nil
  }

  func setBattleRoomIdToOpenForMap(_ id: UUID?) {
    battleRoomIdToOpenForMap = id
  }

  func clearBattleRoomIdToOpenForMap() {
    battleRoomIdToOpenForMap = nil
  }
}
