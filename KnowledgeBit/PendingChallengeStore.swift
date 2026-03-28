// PendingChallengeStore.swift
// 儲存從 Deep Link 進入時待處理的挑戰 ID，供 MainTabView 導航至 ChallengeDetailView

import Combine
import Foundation
import os

private let deepLinkLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.knowledgebit",
  category: "DeepLink"
)

@MainActor
final class PendingChallengeStore: ObservableObject {
  @Published var challengeId: UUID?

  func setPending(_ id: UUID) {
    challengeId = id
  }

  func clear() {
    challengeId = nil
  }

  // MARK: - Retry-enabled Entry Point

  /// App 收到 challenge Deep Link 時呼叫此方法（取代直接呼叫 `setPending`）。
  /// 立即設定 challengeId，並在 500ms 後自動 Retry——
  /// 處理冷啟動時 MainTabView 尚未掛載 onChange 監聽器的競爭條件
  /// （系統 Log 中的 "Timed out waiting for sync reply"）。
  func handleIncomingChallenge(_ id: UUID) {
    deepLinkLogger.info("Deep link received: challenge id=\(id)")
    challengeId = id

    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard let self else { return }
      // challengeId 已被 UI 消費（正常路徑）→ 不重複觸發
      guard self.challengeId == nil else { return }
      deepLinkLogger.info("Deep link retry triggered for challenge id=\(id)")
      self.challengeId = id
    }
  }
}
