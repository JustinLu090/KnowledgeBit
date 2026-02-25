// BattleRoomView.swift
// 對戰房間：準備期 + 最後 1/4 對戰期，僅在對戰期開放戰鬥頁面

import SwiftUI

struct BattleRoomView: View {
  let wordSetID: UUID
  let wordSetTitle: String
  let startDate: Date
  let durationDays: Int
  let invitedMemberIDs: [UUID]

  @State private var now: Date = Date()
  @State private var timer: Timer? = nil

  private var totalSeconds: TimeInterval { TimeInterval(max(1, durationDays)) * 24 * 3600 }
  private var battleStartDate: Date { startDate.addingTimeInterval(totalSeconds * 0.75) }
  private var battleEndDate: Date { startDate.addingTimeInterval(totalSeconds) }

  private var isInBattlePhase: Bool { now >= battleStartDate && now < battleEndDate }
  private var isFinished: Bool { now >= battleEndDate }

  var body: some View {
    VStack(spacing: 16) {
      header

      statusCard

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
            StrategicBattleView(wordSetID: wordSetID, wordSetTitle: wordSetTitle)
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
        VStack(spacing: 10) {
          Text("目前為準備期")
            .font(.headline)
          Text("對戰將在最後 1/4 期間開放")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("距離開戰：\(formatTimeInterval(battleStartDate.timeIntervalSince(now)))")
            .font(.title3.monospacedDigit())
            .padding(.top, 4)
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
      wordSetID: UUID(),
      wordSetTitle: "韓文第六課",
      startDate: Date(),
      durationDays: 7,
      invitedMemberIDs: [UUID(), UUID()]
    )
  }
}
