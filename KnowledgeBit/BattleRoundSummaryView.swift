// BattleRoundSummaryView.swift
// 上一輪結算統整：顯示藍紅雙方在哪些格子投入了多少 KE。

import SwiftUI

struct BattleRoundSummaryView: View {
  let summary: BattleRoundSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("上一輪統整")
        .font(.system(size: 16, weight: .bold, design: .rounded))

      if !summary.blueAllocations.isEmpty {
        teamRow(label: "藍隊", color: .blue, allocations: summary.blueAllocations)
      }
      if !summary.redAllocations.isEmpty {
        teamRow(label: "紅隊", color: .red, allocations: summary.redAllocations)
      }
      if summary.blueAllocations.isEmpty && summary.redAllocations.isEmpty {
        Text("雙方皆未投入 KE")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func teamRow(label: String, color: Color, allocations: [Int: Int]) -> some View {
    HStack(alignment: .top, spacing: 6) {
      Text(label)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(color)
      Text(formatTeamAllocations(allocations))
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }

  /// 例：「格子 #1 投入 100 KE、#5 投入 50 KE」
  private func formatTeamAllocations(_ allocations: [Int: Int]) -> String {
    allocations.sorted(by: { $0.key < $1.key })
      .map { "格子 #\($0.key + 1) 投入 \($0.value) KE" }
      .joined(separator: "、")
  }
}
