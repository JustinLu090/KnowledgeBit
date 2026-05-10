// BattleStatusHeaderView.swift
// 戰鬥畫面頂部狀態列：剩餘 KE 圓盤、結算倒數、佔領與本小時投入摘要。

import SwiftUI

struct BattleStatusHeaderView: View {
  @ObservedObject var vm: StrategicBattleViewModel
  let playerTeamColor: Color
  let isRedTeam: Bool

  var body: some View {
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
      Text("距離結算")
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
    let blueCount = isRedTeam ? vm.enemyOccupiedCount : vm.occupiedCount
    let redCount = isRedTeam ? vm.occupiedCount : vm.enemyOccupiedCount
    return HStack(spacing: 10) {
      HStack(spacing: 6) {
        Text("佔領").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
        Text("藍 \(blueCount)／紅 \(redCount)").font(.system(size: 13, weight: .bold, design: .rounded))
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
