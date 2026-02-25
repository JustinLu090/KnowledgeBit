// BattleEnergyStore.swift
// 集中管理 Battle 可用 KE（以 App Group UserDefaults 永續化）

import Foundation
import SwiftUI

@MainActor
final class BattleEnergyStore: ObservableObject {
  @Published private(set) var availableKE: Int = 0
  private let defaults = AppGroup.sharedUserDefaults()
  private let key = "battle_available_ke"

  init() {
    let stored = defaults?.integer(forKey: key) ?? 0
    availableKE = max(0, stored)
  }

  func addKE(_ delta: Int) {
    guard delta > 0 else { return }
    availableKE += delta
    defaults?.set(availableKE, forKey: key)
    defaults?.synchronize()
  }

  @discardableResult
  func spendKE(_ amount: Int) -> Bool {
    guard amount > 0, availableKE >= amount else { return false }
    availableKE -= amount
    defaults?.set(availableKE, forKey: key)
    defaults?.synchronize()
    return true
  }

  func reset() {
    availableKE = 0
    defaults?.set(0, forKey: key)
    defaults?.synchronize()
  }
}
