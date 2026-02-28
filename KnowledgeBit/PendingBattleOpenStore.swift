// PendingBattleOpenStore.swift
// 由 knowledgebit://battle?wordSetId= 深連結設定，供 MainTabView / LibraryView 導航至該單字集

import Combine
import Foundation

@MainActor
final class PendingBattleOpenStore: ObservableObject {
  @Published var wordSetIdToOpen: UUID?

  func setWordSetIdToOpen(_ id: UUID?) {
    wordSetIdToOpen = id
  }

  func clearWordSetIdToOpen() {
    wordSetIdToOpen = nil
  }
}
