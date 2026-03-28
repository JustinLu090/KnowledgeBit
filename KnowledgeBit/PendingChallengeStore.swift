// PendingChallengeStore.swift
// 儲存從 Deep Link 進入時待處理的挑戰 ID，供 MainTabView 導航至 ChallengeDetailView

import Combine
import Foundation

@MainActor
final class PendingChallengeStore: ObservableObject {
  @Published var challengeId: UUID?

  func setPending(_ id: UUID) {
    challengeId = id
  }

  func clear() {
    challengeId = nil
  }
}
