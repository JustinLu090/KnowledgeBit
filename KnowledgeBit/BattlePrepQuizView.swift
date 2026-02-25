// BattlePrepQuizView.swift
// 準備期測驗：依單字集出題，完成後得分可換算為 KE

import SwiftUI
import SwiftData

struct BattlePrepQuizView: View {
  let wordSetID: UUID

  @Query private var wordSets: [WordSet]
  @StateObject private var energyStore: BattleEnergyStore

  init(wordSetID: UUID) {
    self.wordSetID = wordSetID
    // 設定查詢：僅抓指定 id 的單字集
    let predicate = #Predicate<WordSet> { $0.id == wordSetID }
    _wordSets = Query(filter: predicate)
    _energyStore = StateObject(wrappedValue: BattleEnergyStore(namespace: wordSetID.uuidString))
  }

  var body: some View {
    Group {
      if let ws = wordSets.first {
        MultipleChoiceQuizView(wordSet: ws)
          .environmentObject(energyStore)
      } else {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 36))
            .foregroundStyle(.orange)
          Text("找不到此單字集")
            .font(.headline)
          Text("請返回並重試")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
      }
    }
    .navigationTitle("準備期測驗")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    BattlePrepQuizView(wordSetID: UUID())
  }
}
