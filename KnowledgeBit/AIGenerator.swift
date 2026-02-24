// AIGenerator.swift
// 簡單的本地 stub，用來滿足 UI 的呼叫並在沒有真實 AI 時提供範例卡片

import Foundation
#if canImport(UIKit)
import UIKit
#endif

actor AIGenerator {
  struct GeneratedCard {
    let title: String
    let content: String
    let deck: String
  }

  /// 以關鍵字產生示例卡片（模擬 async AI 呼叫）
  func generateCards(topic: String) async throws -> [GeneratedCard] {
    // 模擬非同步延遲
    try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
    let cards = [
      GeneratedCard(title: "\(topic) 01", content: "簡短說明或範例內容。", deck: topic),
      GeneratedCard(title: "\(topic) 02", content: "補充說明或範例內容。", deck: topic)
    ]
    return cards
  }

  /// 根據影像產生示例卡片（模擬）
  func generateCardsFromImage(image: UIImage) async throws -> [GeneratedCard] {
    // 模擬非同步延遲
    try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
    let cards = [
      GeneratedCard(title: "Image Card 01", content: "由影像內容自動產生的說明（範例）。", deck: "Image Deck"),
      GeneratedCard(title: "Image Card 02", content: "由影像內容自動產生的補充說明（範例）。", deck: "Image Deck")
    ]
    return cards
  }
}
