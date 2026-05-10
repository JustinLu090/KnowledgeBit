// FailedSubmissionQueue.swift
// 封裝戰鬥結算的「失敗 bucket 重試佇列」：
//   * 單一 bucket 提交失敗時保留 allocation 快照（非 live pendingKE）。
//   * 下次結算先嘗試 retry，每個 bucket 用各自儲存的 allocation。
//   * Persisted via BattlePendingStore，跨 app 重啟仍保留。

import Foundation
import os

@MainActor
final class FailedSubmissionQueue {
  private let roomId: UUID
  private let store: BattlePendingStore

  /// bucket 起始時間 → 當時的 allocation 快照
  private var entries: [Date: [Int: Int]] = [:]

  /// 目前正在送出的 bucket epoch 集合，防止 timer 雙觸發或 retry 與 settlement 撞車。
  private var inFlight: Set<TimeInterval> = []

  init(roomId: UUID, store: BattlePendingStore? = nil) {
    self.roomId = roomId
    self.store = store ?? BattlePendingStore()
  }

  /// 從持久化還原失敗佇列。應於 loadInitialBoard 階段呼叫。
  func restore() {
    let saved = store.loadFailedSubmissions(roomId: roomId)
    if !saved.isEmpty {
      entries.merge(saved) { _, new in new }
      #if DEBUG
      AppLog.battle.info("[Battle] restored \(saved.count) failed submission(s) from persistence")
      #endif
    }
  }

  // MARK: - In-flight bookkeeping

  func tryBeginFlight(bucket: Date) -> Bool {
    let key = bucket.timeIntervalSince1970
    guard !inFlight.contains(key) else { return false }
    inFlight.insert(key)
    return true
  }

  func endFlight(bucket: Date) {
    inFlight.remove(bucket.timeIntervalSince1970)
  }

  func isInFlight(bucket: Date) -> Bool {
    inFlight.contains(bucket.timeIntervalSince1970)
  }

  // MARK: - Failed entries

  /// 保留 bucket 失敗的 allocation 快照（呼叫端應傳入 settle 當下的快照，而非 live pendingKE）。
  func record(bucket: Date, allocations: [Int: Int]) {
    entries[bucket] = allocations
    persist()
  }

  /// 取得目前所有失敗 bucket（依 bucket 時間排序）。
  func sortedBuckets() -> [Date] {
    entries.keys.sorted()
  }

  func allocations(for bucket: Date) -> [Int: Int]? {
    entries[bucket]
  }

  func remove(bucket: Date) {
    entries.removeValue(forKey: bucket)
  }

  /// 應於批次 retry 結束時呼叫，把目前狀態寫回持久化。
  func persist() {
    store.saveFailedSubmissions(roomId: roomId, submissions: entries)
  }
}
