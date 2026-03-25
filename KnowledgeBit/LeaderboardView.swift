// LeaderboardView.swift
// 好友本週 EXP 排行榜

import SwiftUI

struct LeaderboardView: View {
  let entries: [LeaderboardEntry]
  let isLoading: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("本週排行榜")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.primary)
        Spacer()
        Text("以本週 EXP 計算")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 4)

      if isLoading {
        HStack {
          Spacer()
          ProgressView()
          Spacer()
        }
        .padding(32)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
      } else if entries.isEmpty {
        HStack {
          Spacer()
          VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
              .font(.system(size: 36))
              .foregroundStyle(.tertiary)
            Text("加入好友後即可查看排行榜")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }
          .padding(32)
          Spacer()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
      } else {
        VStack(spacing: 0) {
          // Top 3 podium (if enough entries)
          if entries.count >= 3 {
            podiumSection
              .padding(.bottom, 8)
          }

          // Full ranked list
          ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            LeaderboardRow(entry: entry, isLast: index == entries.count - 1)
          }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
      }
    }
  }

  // MARK: - Podium (top 3)

  private var podiumSection: some View {
    HStack(alignment: .bottom, spacing: 8) {
      // 2nd place
      if entries.count > 1 {
        PodiumColumn(entry: entries[1], podiumHeight: 60, medal: "🥈")
      }
      // 1st place
      PodiumColumn(entry: entries[0], podiumHeight: 80, medal: "🥇")
      // 3rd place
      if entries.count > 2 {
        PodiumColumn(entry: entries[2], podiumHeight: 44, medal: "🥉")
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
  }
}

// MARK: - PodiumColumn

private struct PodiumColumn: View {
  let entry: LeaderboardEntry
  let podiumHeight: CGFloat
  let medal: String

  var body: some View {
    VStack(spacing: 6) {
      Text(medal)
        .font(.system(size: 20))
      AvatarView(avatarURL: entry.avatarURL, size: 40)
        .overlay(
          entry.isCurrentUser
          ? Circle().stroke(Color.blue, lineWidth: 2)
          : nil
        )
      Text(entry.displayName)
        .font(.system(size: 11, weight: entry.isCurrentUser ? .bold : .medium))
        .foregroundStyle(entry.isCurrentUser ? .blue : .primary)
        .lineLimit(1)
      Text("\(entry.weeklyExp) EXP")
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
      Rectangle()
        .fill(entry.isCurrentUser ? Color.blue.opacity(0.2) : Color(.systemFill))
        .frame(height: podiumHeight)
        .cornerRadius(6)
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - LeaderboardRow

private struct LeaderboardRow: View {
  let entry: LeaderboardEntry
  let isLast: Bool

  var rankColor: Color {
    switch entry.rank {
    case 1: return .yellow
    case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
    case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
    default: return .secondary
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 14) {
        // Rank badge
        ZStack {
          Circle()
            .fill(entry.rank <= 3 ? rankColor.opacity(0.15) : Color(.systemFill))
            .frame(width: 32, height: 32)
          Text("#\(entry.rank)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(entry.rank <= 3 ? rankColor : .secondary)
        }

        AvatarView(avatarURL: entry.avatarURL, size: 40)

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(entry.displayName)
              .font(.system(size: 15, weight: entry.isCurrentUser ? .semibold : .regular))
              .foregroundStyle(entry.isCurrentUser ? .blue : .primary)
            if entry.isCurrentUser {
              Text("我")
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue)
                .cornerRadius(4)
            }
          }
          Text("Lv.\(entry.level)")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text("\(entry.weeklyExp)")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(entry.isCurrentUser ? .blue : .primary)
          Text("EXP")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(entry.isCurrentUser ? Color.blue.opacity(0.05) : Color.clear)

      if !isLast {
        Divider().padding(.leading, 60)
      }
    }
  }
}
