// BattleRoomView.swift
// 對戰房間：準備期 + 最後 1/4 對戰期，僅在對戰期開放戰鬥頁面

import SwiftUI

struct BattleRoomView: View {
  let roomId: UUID
  let wordSetID: UUID
  let wordSetTitle: String
  let startDate: Date
  let durationDays: Int
  let invitedMemberIDs: [UUID]
  /// 創辦人 = 藍隊；被邀請成員 = 紅隊。nil 時視為目前使用者為創辦人（藍隊）。
  let creatorId: UUID?

  @State private var now: Date = Date()
  @State private var timer: Timer? = nil
  @EnvironmentObject private var energyStore: BattleEnergyStore
  @EnvironmentObject private var authService: AuthService

  /// 目前使用者是否為藍隊（創辦人）
  private var isBlueTeam: Bool {
    guard let cid = creatorId, let me = authService.currentUserId else { return true }
    return me == cid
  }

  private var teamLabel: String { isBlueTeam ? "藍隊" : "紅隊" }
  private var teamColor: Color { isBlueTeam ? Color.blue : Color.red }

  private var totalSeconds: TimeInterval { TimeInterval(max(1, durationDays)) * 24 * 3600 }
  private var battleStartDate: Date { startDate.addingTimeInterval(totalSeconds * 0.75) }
  private var battleEndDate: Date { startDate.addingTimeInterval(totalSeconds) }

  private var isInBattlePhase: Bool { now >= battleStartDate && now < battleEndDate }
  private var isFinished: Bool { now >= battleEndDate }

  var body: some View {
    VStack(spacing: 16) {
      header

      statusCard

      // ⚠️ 測試用：無視時間，直接進入戰鬥盤面（之後正式開發可移除）
      NavigationLink {
        StrategicBattleView(roomId: roomId, wordSetID: wordSetID, creatorId: creatorId, wordSetTitle: wordSetTitle)
      } label: {
        HStack {
          Image(systemName: "hammer.fill")
          Text("（測試）直接進入戰鬥盤面")
            .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
        .cornerRadius(12)
      }

      Spacer(minLength: 0)

      if isFinished {
        Text("本次對戰已結束")
          .font(.headline)
          .foregroundStyle(.secondary)
      } else if isInBattlePhase {
        VStack(spacing: 12) {
          Text("對戰期倒數：\(formatTimeInterval(battleEndDate.timeIntervalSince(now)))")
            .font(.title3.monospacedDigit())
            .foregroundStyle(.red)

          NavigationLink {
            StrategicBattleView(roomId: roomId, wordSetID: wordSetID, creatorId: creatorId, wordSetTitle: wordSetTitle)
          } label: {
            HStack {
              Image(systemName: "swords")
              Text("進入戰鬥")
                .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundStyle(.white)
            .cornerRadius(12)
          }
          .padding(.horizontal)
        }
        .padding()
      } else {
        VStack(spacing: 12) {
          Text("目前為準備期")
            .font(.headline)
          Text("對戰將在最後 1/4 期間開放")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("距離開戰：\(formatTimeInterval(battleStartDate.timeIntervalSince(now)))")
            .font(.title3.monospacedDigit())
            .padding(.top, 4)

          VStack(alignment: .leading, spacing: 8) {
            Text("準備期測驗")
              .font(.subheadline.weight(.semibold))
            Text("透過選擇題測驗賺取 KE，之後在正式對戰中可用來佔領格子。")
              .font(.caption)
              .foregroundStyle(.secondary)

            NavigationLink {
              BattlePrepQuizView(wordSetID: wordSetID, roomId: roomId, creatorId: creatorId)
            } label: {
              HStack {
                Image(systemName: "bolt.circle")
                Text("進行準備期選擇題測驗")
                  .fontWeight(.semibold)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.blue.opacity(0.15))
              .foregroundStyle(.blue)
              .cornerRadius(12)
            }
          }
          .padding()
          .background(Color(.secondarySystemGroupedBackground))
          .cornerRadius(12)
        }
        .padding()
      }
    }
    .padding()
    .navigationTitle("對戰房間")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { startTimer() }
    .onDisappear { stopTimer() }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(wordSetTitle)
        .font(.title3.bold())
      Text("時長：\(durationDays) 天 ・ 對戰期為最後 1/4")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var statusCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("您的隊伍", systemImage: "person.2.fill")
        Spacer()
        Text(teamLabel)
          .font(.subheadline.bold())
          .foregroundStyle(teamColor)
      }
      Divider().padding(.vertical, 2)
      HStack {
        Label("開始時間", systemImage: "clock")
        Spacer()
        Text(formatDate(startDate))
          .font(.subheadline)
      }
      HStack {
        Label("對戰開放", systemImage: "flag.checkered")
        Spacer()
        Text(formatDate(battleStartDate))
          .font(.subheadline)
      }
      HStack {
        Label("結束時間", systemImage: "calendar")
        Spacer()
        Text(formatDate(battleEndDate))
          .font(.subheadline)
      }
      Divider().padding(.vertical, 6)
      HStack {
        Label("已邀請成員", systemImage: "person.2")
        Spacer()
        Text("\(invitedMemberIDs.count) 位")
      }
      Divider().padding(.vertical, 6)
      HStack {
        Label("目前可用 KE", systemImage: "bolt.circle")
        Spacer()
        Text("\(energyStore.availableKE(for: wordSetID.uuidString))")
          .font(.subheadline.bold())
      }
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
  }

  private func startTimer() {
    stopTimer()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      now = Date()
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  private func formatDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: date)
  }

  private func formatTimeInterval(_ ti: TimeInterval) -> String {
    let seconds = max(0, Int(ti))
    let d = seconds / 86400
    let h = (seconds % 86400) / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if d > 0 {
      return String(format: "%dd %02d:%02d:%02d", d, h, m, s)
    } else {
      return String(format: "%02d:%02d:%02d", h, m, s)
    }
  }
}

#Preview {
  NavigationStack {
    BattleRoomView(
      roomId: UUID(),
      wordSetID: UUID(),
      wordSetTitle: "英文",
      startDate: Date(),
      durationDays: 7,
      invitedMemberIDs: [UUID(), UUID()],
      creatorId: nil
    )
    .environmentObject(BattleEnergyStore())
    .environmentObject(AuthService())
  }
}
