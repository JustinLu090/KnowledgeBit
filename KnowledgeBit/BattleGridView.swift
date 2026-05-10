// BattleGridView.swift
// 4×4 戰鬥棋盤：依當前格子狀態渲染顏色、HP 條、選取與可進攻邊框；點擊切換選取。

import SwiftUI

struct BattleGridView: View {
  @ObservedObject var vm: StrategicBattleViewModel
  let playerTeamColor: Color
  let enemyTeamColor: Color
  let neutralColor: Color
  let gridMaxSide: CGFloat

  var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height, gridMaxSide)
      let cellGap: CGFloat = 10
      let cellSide = (side - cellGap * 3) / 4

      ZStack {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(.ultraThinMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(Color.white.opacity(0.12), lineWidth: 1)
          )

        LazyVGrid(
          columns: Array(repeating: GridItem(.fixed(cellSide), spacing: cellGap), count: 4),
          spacing: cellGap
        ) {
          ForEach(0..<BattleConstants.totalCells, id: \.self) { id in
            cellView(id: id, size: cellSide)
              .onTapGesture { handleTap(id) }
              .disabled(vm.isSettlementLocked)
          }
        }
        .padding(10)
      }
      .frame(width: side, height: side)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minHeight: 360, maxHeight: gridMaxSide + 40)
  }

  private func cellView(id: Int, size: CGFloat) -> some View {
    let cell = vm.cell(for: id)
    let isSelected = vm.selectedCellID == id

    let baseColor: Color = {
      switch cell.owner {
      case .neutral: return neutralColor
      case .player: return playerTeamColor
      case .enemy: return enemyTeamColor
      }
    }()

    let borderState: StrategicGridCellView.BorderState = {
      if isSelected { return .selected }
      if vm.isAttackableTarget(id) { return .neighbor }
      return .none
    }()

    let hpFraction = CGFloat(cell.hpNow) / CGFloat(max(1, cell.hpMax))

    return StrategicGridCellView(
      size: size,
      baseColor: baseColor,
      hpFraction: hpFraction,
      pendingLabel: vm.pendingValue(for: id),
      borderState: borderState
    )
  }

  private func handleTap(_ id: Int) {
    let cell = vm.cell(for: id)
    if cell.owner == .player || vm.isAttackableTarget(id) {
      vm.setSelected(cellID: (vm.selectedCellID == id ? nil : id))
    } else {
      vm.setSelected(cellID: nil)
    }
  }
}
