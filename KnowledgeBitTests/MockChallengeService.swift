// MockChallengeService.swift
// ChallengeServicing 的測試替身：以 stub 結果或預先注入的 throwable 取代實際網路呼叫；
// 同時計數每個 API 被呼叫的次數，方便驗證行為。

import Foundation
@testable import KnowledgeBit

@MainActor
final class MockChallengeService: ChallengeServicing {
  // MARK: - Stubs

  /// 下次 fetchChallenge 應回傳的結果或丟出的錯誤。預設拋 NotStubbedError。
  var fetchChallengeStub: Result<ChallengeSession, Error>?
  var fetchChallengeCardsByIdsStub: Result<[ChallengeCard], Error>?
  var fetchChallengeCardsStub: Result<[ChallengeCard], Error>?
  var respondToChallengeStub: Result<Void, Error>?

  // MARK: - Call tracking

  private(set) var fetchChallengeCallCount = 0
  private(set) var fetchChallengeCardsByIdsCallCount = 0
  private(set) var fetchChallengeCardsCallCount = 0
  private(set) var respondToChallengeCallCount = 0

  /// 最後一次 respondToChallenge 收到的參數（驗證測試用）。
  private(set) var lastRespondParams: (
    challengeId: UUID, score: Int, total: Int, timeSpent: TimeInterval, combo: Int
  )?

  // MARK: - ChallengeServicing

  func fetchChallenge(id: UUID) async throws -> ChallengeSession {
    fetchChallengeCallCount += 1
    return try unwrap(fetchChallengeStub, label: "fetchChallenge")
  }

  func fetchChallengeCards(wordSetId: UUID) async throws -> [ChallengeCard] {
    fetchChallengeCardsCallCount += 1
    return try unwrap(fetchChallengeCardsStub, label: "fetchChallengeCards")
  }

  func fetchChallengeCardsByIds(_ cardIds: [UUID]) async throws -> [ChallengeCard] {
    fetchChallengeCardsByIdsCallCount += 1
    return try unwrap(fetchChallengeCardsByIdsStub, label: "fetchChallengeCardsByIds")
  }

  func respondToChallenge(
    challengeId: UUID, score: Int, total: Int, timeSpent: TimeInterval, combo: Int
  ) async throws {
    respondToChallengeCallCount += 1
    lastRespondParams = (challengeId, score, total, timeSpent, combo)
    if let stub = respondToChallengeStub {
      switch stub {
      case .success: return
      case .failure(let err): throw err
      }
    }
    // 預設成功（多數測試只關心 fetchChallenge 的回傳）
  }

  // MARK: - Helpers

  private func unwrap<T>(_ stub: Result<T, Error>?, label: String) throws -> T {
    guard let stub else {
      throw NotStubbedError(label: label)
    }
    switch stub {
    case .success(let value): return value
    case .failure(let err): throw err
    }
  }
}

struct NotStubbedError: Error, CustomStringConvertible {
  let label: String
  var description: String { "\(label) called without a stub" }
}

struct MockNetworkError: Error, LocalizedError {
  var errorDescription: String? { "mock network failure" }
}
