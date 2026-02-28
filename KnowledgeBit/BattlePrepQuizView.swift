// BattlePrepQuizView.swift
// 準備期測驗：依單字集出題，完成後得分可換算為 KE

import SwiftUI
import SwiftData

struct BattlePrepQuizView: View {
  let wordSetID: UUID
  /// 若存在，完成測驗後可直接導向此對戰房間的戰略盤面
  let roomId: UUID?
  /// 對戰房間創辦人（藍隊）；被邀請 = 紅隊，傳給戰鬥盤面用
  let creatorId: UUID?

  @Query private var wordSets: [WordSet]
  @EnvironmentObject private var energyStore: BattleEnergyStore

  init(wordSetID: UUID, roomId: UUID? = nil, creatorId: UUID? = nil) {
    self.wordSetID = wordSetID
    self.roomId = roomId
    self.creatorId = creatorId
    // 設定查詢：僅抓指定 id 的單字集
    let predicate = #Predicate<WordSet> { $0.id == wordSetID }
    _wordSets = Query(filter: predicate)
  }

  var body: some View {
    Group {
      if let ws = wordSets.first {
        MultipleChoiceQuizView(wordSet: ws, roomId: roomId, creatorId: creatorId)
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
