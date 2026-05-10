// ChallengeServicing.swift
// 抽象介面：ChallengeDetailViewModel 透過此協定操作非同步挑戰相關 API。
// 真實實作為 ChallengeService（透過 Supabase 呼叫）；測試可注入 mock 取代。

import Foundation

protocol ChallengeServicing {
  func fetchChallenge(id: UUID) async throws -> ChallengeSession
  func fetchChallengeCards(wordSetId: UUID) async throws -> [ChallengeCard]
  func fetchChallengeCardsByIds(_ cardIds: [UUID]) async throws -> [ChallengeCard]
  func respondToChallenge(
    challengeId: UUID,
    score: Int,
    total: Int,
    timeSpent: TimeInterval,
    combo: Int
  ) async throws
}

extension ChallengeService: ChallengeServicing {}
