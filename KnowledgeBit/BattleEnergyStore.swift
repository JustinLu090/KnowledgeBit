// BattleEnergyStore.swift
// 集中管理 Battle 可用 KE（以 App Group UserDefaults 永續化）

import Combine
import Foundation
import SwiftUI

@MainActor
final class BattleEnergyStore: ObservableObject {
  /// 每個 namespace（目前用單字集 ID 字串）對應的 KE
  @Published private(set) var keByNamespace: [String: Int] = [:]
  private let defaults: UserDefaults?
  private let key = "battle_available_ke_by_namespace"

  init() {
    // 勿在屬性初始器呼叫 `AppGroup.sharedUserDefaults()`（Swift 6：預設參數／儲存屬性初始器為 nonisolated）
    self.defaults = UserDefaults(suiteName: AppGroup.identifier)
    if
      let data = defaults?.data(forKey: key),
      let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
    {
      keByNamespace = decoded
    } else {
      keByNamespace = [:]
    }
  }

  /// 查詢指定 namespace 的目前 KE（沒有記錄時回傳 0）
  func availableKE(for namespace: String) -> Int {
    keByNamespace[namespace] ?? 0
  }

  /// 為指定 namespace 增加 KE
  func addKE(_ delta: Int, namespace: String) {
    guard delta > 0 else { return }
    let current = keByNamespace[namespace] ?? 0
    keByNamespace[namespace] = current + delta
    persist()
  }

  @discardableResult
  func spendKE(_ amount: Int, namespace: String) -> Bool {
    guard amount > 0 else { return false }
    let current = keByNamespace[namespace] ?? 0
    guard current >= amount else { return false }
    keByNamespace[namespace] = current - amount
    persist()
    return true
  }

  /// 清除某個 namespace 的 KE
  func reset(namespace: String) {
    keByNamespace[namespace] = 0
    persist()
  }

  private func persist() {
    guard let defaults else { return }
    if let data = try? JSONEncoder().encode(keByNamespace) {
      defaults.set(data, forKey: key)
      defaults.synchronize()
    }
  }
}
