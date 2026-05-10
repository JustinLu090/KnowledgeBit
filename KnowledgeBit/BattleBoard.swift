// BattleBoard.swift
// 戰鬥棋盤的純座標運算（純函式、零副作用），方便獨立單元測試。
// 不依賴任何 instance state；所有 API 皆 nonisolated 可從任何 actor 呼叫。

import Foundation

enum BattleBoard {
  /// 給定格子 id（0..<side²），回傳 4 鄰格子 id（上下左右；過邊界會跳過）。
  static func neighbors(of id: Int, side: Int = BattleConstants.boardSide) -> [Int] {
    let row = id / side
    let col = id % side
    var n: [Int] = []
    if row > 0 { n.append((row - 1) * side + col) }       // up
    if row < side - 1 { n.append((row + 1) * side + col) } // down
    if col > 0 { n.append(row * side + (col - 1)) }       // left
    if col < side - 1 { n.append(row * side + (col + 1)) } // right
    return n
  }

  /// 是否為邊緣（最外環）格子。
  static func isEdgeCell(_ id: Int, side: Int = BattleConstants.boardSide) -> Bool {
    let row = id / side
    let col = id % side
    return row == 0 || row == side - 1 || col == 0 || col == side - 1
  }
}
