// RewardedChallengeStore.swift
// 已發放 EXP 的挑戰 ID 持久化集合：
//   * 用 Array 保留插入順序，新項目 append 到尾端。
//   * 超過 capacity 後從最舊（front）FIFO 淘汰，避免 UserDefaults 無限膨脹。
//   * 跨 session 持久化於 UserDefaults。

import Foundation

@MainActor
final class RewardedChallengeStore {
  nonisolated private static let defaultKey = "kb_rewarded_challenge_ids"
  /// 預設保留 200 筆（每筆 UUID 字串約 36 byte，總計 ≈ 7KB）。
  nonisolated static let defaultCapacity = 200

  private let defaults: UserDefaults
  private let key: String
  private let capacity: Int

  init(
    defaults: UserDefaults = .standard,
    key: String = RewardedChallengeStore.defaultKey,
    capacity: Int = RewardedChallengeStore.defaultCapacity
  ) {
    self.defaults = defaults
    self.key = key
    self.capacity = capacity
  }

  /// 是否已對該挑戰發放 EXP。
  func contains(_ challengeId: UUID) -> Bool {
    load().contains(challengeId.uuidString)
  }

  /// 紀錄此挑戰已發放 EXP；若超出 capacity 則 FIFO 淘汰最舊紀錄。
  /// 已存在則不重複加入。
  /// - Returns: 是否實際新增（false 代表此 ID 早已存在）。
  @discardableResult
  func record(_ challengeId: UUID) -> Bool {
    var rewarded = load()
    let key = challengeId.uuidString
    guard !rewarded.contains(key) else { return false }
    rewarded.append(key)
    if rewarded.count > capacity {
      rewarded.removeFirst(rewarded.count - capacity)
    }
    defaults.set(rewarded, forKey: self.key)
    return true
  }

  /// 取得目前的記錄數（測試用）。
  var count: Int { load().count }

  /// 清空所有紀錄（測試用）。
  func clear() {
    defaults.removeObject(forKey: key)
  }

  private func load() -> [String] {
    defaults.stringArray(forKey: key) ?? []
  }
}
