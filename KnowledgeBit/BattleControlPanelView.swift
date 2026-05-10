// BattleControlPanelView.swift
// 戰鬥畫面底部互動 sheet：未選格時顯示概況與一鍵建議；選取格時顯示加固/進攻面板（HP、KE 滑桿、清除/完成）。

import SwiftUI

struct BattleControlPanelView: View {
  @ObservedObject var vm: StrategicBattleViewModel
  let playerTeamColor: Color
  let enemyTeamColor: Color

  var body: some View {
    VStack(spacing: 0) {
      Capsule()
        .fill(Color.secondary.opacity(0.25))
        .frame(width: 44, height: 5)
        .padding(.top, 10)
        .padding(.bottom, 12)

      if let id = vm.selectedCellID {
        selectedPanel(cellID: id)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      } else {
        unselectedPanel
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(Color.white.opacity(0.10), lineWidth: 1)
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 10)
    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: vm.selectedCellID)
  }

  // MARK: - Unselected

  private var unselectedPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("戰場概況")
        .font(.system(size: 16, weight: .bold, design: .rounded))

      Text(overviewText)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Button {
        autoAllocateSuggestion()
      } label: {
        Text("一鍵分配建議")
          .font(.system(size: 14, weight: .bold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .disabled(vm.isSettlementLocked || vm.remainingKE == 0)
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }

  private var overviewText: String {
    if vm.isSettlementLocked {
      return "整點前最後 2 分鐘進入鎖定：禁止分配積分，等待結算。"
    }
    let attackables = (0..<BattleConstants.totalCells).filter { vm.isAttackableTarget($0) }.count
    return "可進攻目標：\(attackables) 格。點選白色虛線邊框的格子進行進攻，或點選己方格子加固。"
  }

  private func autoAllocateSuggestion() {
    if let target = (0..<BattleConstants.totalCells).first(where: { vm.isAttackableTarget($0) }) {
      vm.setSelected(cellID: target)
      vm.updatePendingKE(for: target, to: min(BattleConstants.autoAllocateSuggestion, vm.remainingKE))
    }
  }

  // MARK: - Selected

  private func selectedPanel(cellID: Int) -> some View {
    let cell = vm.cell(for: cellID)
    let pending = vm.pendingValue(for: cellID)
    let isOwn = cell.owner == .player

    let actionTitle = isOwn ? "加固" : "進攻"
    let actionColor = isOwn ? playerTeamColor : enemyTeamColor
    // 加固時：投入 KE 不得讓 HP 超過 400（上限 = 400 - hpNow）；進攻時：單格上限 400
    let cellCap = vm.maxAllowedKE(for: cellID)
    let maxSlider = min(cellCap, max(0, vm.remainingKE + pending))

    let canCommit: Bool = {
      if vm.isSettlementLocked { return false }
      if pending <= 0 { return false }
      if isOwn { return true }
      return vm.isAttackableTarget(cellID)
    }()

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("格子 #\(cellID + 1)")
          .font(.system(size: 16, weight: .bold, design: .rounded))

        Spacer()

        Button {
          vm.setSelected(cellID: nil)
        } label: {
          Text(actionTitle)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(actionColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(actionColor.opacity(canCommit ? 0.16 : 0.08)))
        }
        .buttonStyle(.plain)
        .disabled(!canCommit)
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Text("HP 現在")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
          Text("\(cell.hpNow)/\(cell.hpMax)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
        }
      }
      .padding(.top, 2)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("投入 KE")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Text("\(pending)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
        }

        Slider(
          value: Binding(
            get: { Double(pending) },
            set: { vm.updatePendingKE(for: cellID, to: Int($0.rounded())) }
          ),
          in: 0...Double(max(maxSlider, 1)),
          step: 1
        )
        .disabled(vm.isSettlementLocked || maxSlider == 0)

        Text("可用剩餘：\(vm.remainingKE) KE")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.top, 4)

      HStack(spacing: 10) {
        Button { vm.updatePendingKE(for: cellID, to: 0) } label: {
          Text("清除")
            .font(.system(size: 14, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(vm.isSettlementLocked || pending == 0)

        Button { vm.setSelected(cellID: nil) } label: {
          Text("完成")
            .font(.system(size: 14, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
      }
      .padding(.top, 2)
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }
}
