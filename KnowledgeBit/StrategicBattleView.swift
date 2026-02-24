// StrategicBattleView.swift

import SwiftUI

struct StrategicBattleView: View {
  @StateObject private var vm = StrategicBattleViewModel()

  private let gridSize: CGFloat = 360
  private let gridPadding: CGFloat = 16

  private let playerTeamColor: Color = .blue
  private let enemyTeamColor: Color = .red
  private let neutralColor: Color = Color.black.opacity(0.35)

  var body: some View {
    NavigationStack {
      VStack(spacing: 14) {
        gridArea
          .padding(.horizontal, gridPadding)

        Spacer(minLength: 0)

        bottomSheet
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("對戰")
      .navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .top, spacing: 0) {
        statusHeader
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, 10)
      }
      .overlay(lockOverlay)
    }
  }

  // MARK: - Header

  private var statusHeader: some View {
    HStack(spacing: 12) {
      energyDial

      VStack(alignment: .leading, spacing: 6) {
        timerChip
        territorySummary
      }

      Spacer()
    }
  }

  private var energyDial: some View {
    ZStack {
      Circle().fill(Color.black.opacity(0.06))
      EnergyPulseRing(color: playerTeamColor).padding(6)

      VStack(spacing: 2) {
        Text("\(vm.remainingKE)")
          .font(.system(size: 18, weight: .bold, design: .rounded))
        Text("KE")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: 72, height: 72)
  }

  private var timerChip: some View {
    HStack(spacing: 8) {
      Text("距整點結算")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(formatMMSS(vm.secondsToTopOfHour))
        .font(.system(size: 13, weight: .bold, design: .monospaced))
        .foregroundStyle(vm.isSettlementLocked ? .red : .primary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.thinMaterial, in: Capsule())
  }

  private var territorySummary: some View {
    HStack(spacing: 10) {
      HStack(spacing: 6) {
        Text("佔領").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
        Text("\(vm.occupiedCount)/16").font(.system(size: 13, weight: .bold, design: .rounded))
      }
      Divider().frame(height: 16)
      HStack(spacing: 6) {
        Text("本小時投入").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
        Text("\(vm.totalInvestedThisHour)").font(.system(size: 13, weight: .bold, design: .rounded))
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.thinMaterial, in: Capsule())
  }

  // MARK: - Grid

  private var gridArea: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height, gridSize)
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
          ForEach(0..<16, id: \.self) { id in
            cellView(id: id, size: cellSide)
              .onTapGesture { handleCellTap(id) }
              .disabled(vm.isSettlementLocked)
          }
        }
        .padding(14)
      }
      .frame(width: side, height: side)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(height: min(gridSize, 420))
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

  private func handleCellTap(_ id: Int) {
    let cell = vm.cell(for: id)
    if cell.owner == .player || vm.isAttackableTarget(id) {
      vm.setSelected(cellID: (vm.selectedCellID == id ? nil : id))
    } else {
      vm.setSelected(cellID: nil)
    }
  }

  // MARK: - Bottom Sheet

  private var bottomSheet: some View {
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

  private func selectedPanel(cellID: Int) -> some View {
    let cell = vm.cell(for: cellID)
    let pending = vm.pendingValue(for: cellID)
    let isOwn = cell.owner == .player

    let actionTitle = isOwn ? "加固" : "進攻"
    let actionColor = isOwn ? playerTeamColor : enemyTeamColor
    let maxSlider = max(0, vm.remainingKE + pending)

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

      // ✅ 只保留 HP 現在，刪除「HP 結算後預測」
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
          in: 0...Double(maxSlider),
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

  private var overviewText: String {
    if vm.isSettlementLocked {
      return "整點前最後 2 分鐘進入鎖定：禁止分配積分，等待結算。"
    }
    let attackables = (0..<16).filter { vm.isAttackableTarget($0) }.count
    return "可進攻目標：\(attackables) 格。點選白色虛線邊框的格子進行進攻，或點選己方格子加固。"
  }

  private func autoAllocateSuggestion() {
    if let target = (0..<16).first(where: { vm.isAttackableTarget($0) }) {
      vm.setSelected(cellID: target)
      vm.updatePendingKE(for: target, to: min(150, vm.remainingKE))
    }
  }

  // MARK: - Lock overlay

  @ViewBuilder
  private var lockOverlay: some View {
    if vm.isSettlementLocked {
      VStack(spacing: 10) {
        Text("結算中…")
          .font(.system(size: 18, weight: .bold, design: .rounded))
        Text("整點前最後 2 分鐘已鎖定，禁止新的積分分配。")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.white.opacity(0.12), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 10)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black.opacity(0.12))
      .transition(.opacity)
    }
  }

  private func formatMMSS(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
  }
}

private struct EnergyPulseRing: View {
  let color: Color
  @State private var pulse = false

  var body: some View {
    ZStack {
      Circle().stroke(color.opacity(0.45), lineWidth: 2)
      Circle()
        .stroke(color.opacity(0.35), lineWidth: 3)
        .scaleEffect(pulse ? 1.14 : 0.92)
        .opacity(pulse ? 0.08 : 0.30)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
    }
    .onAppear { pulse = true }
  }
}
