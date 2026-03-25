// AchievementsView.swift
// 成就頁面：以 Grid 顯示所有成就，區分已解鎖與未解鎖

import SwiftUI
import SwiftData

// MARK: - AchievementsView

struct AchievementsView: View {
  @ObservedObject private var service = AchievementService.shared
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var dailyQuestService: DailyQuestService
  @Query(sort: \StudyLog.date, order: .reverse) private var studyLogs: [StudyLog]

  private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          CompactPageHeader("成就")

          // 進度概覽
          progressHeader
            .padding(.horizontal, 20)

          // 成就 Grid
          LazyVGrid(columns: columns, spacing: 16) {
            ForEach(AchievementService.catalog) { template in
              let achievement = service.achievements.first { $0.id == template.id } ?? template
              AchievementCell(achievement: achievement)
            }
          }
          .padding(.horizontal, 20)

          Spacer().frame(height: 32)
        }
      }
      .background(Color(.systemGroupedBackground))
      .toolbar(.hidden, for: .navigationBar)
      .onAppear {
        let streak = studyLogs.currentStreak()
        AchievementService.shared.evaluate(level: experienceStore.level, streak: streak)
        StatisticsManager.shared.flushYesterdayIfNeeded(
          modelContext: modelContext,
          dailyQuestService: dailyQuestService
        )
      }
    }
  }

  // MARK: - Progress Header

  private var progressHeader: some View {
    VStack(spacing: 12) {
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 4) {
          Text("已解鎖")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
          Text("\(service.unlockedCount) / \(service.totalCount)")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.primary)
        }
        Spacer()
        ZStack {
          Circle()
            .stroke(Color(.systemFill), lineWidth: 8)
          Circle()
            .trim(from: 0, to: service.totalCount > 0
                  ? CGFloat(service.unlockedCount) / CGFloat(service.totalCount)
                  : 0)
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(-90))
          Text("\(Int(service.totalCount > 0 ? Double(service.unlockedCount) / Double(service.totalCount) * 100 : 0))%")
            .font(.system(size: 14, weight: .semibold))
        }
        .frame(width: 64, height: 64)
      }

      // Rarity breakdown
      HStack(spacing: 12) {
        ForEach(AchievementRarity.allCases, id: \.rawValue) { rarity in
          let count = service.achievements.filter { $0.rarity == rarity && $0.isUnlocked }.count
          let total = AchievementService.catalog.filter { $0.rarity == rarity }.count
          rarityBadge(rarity: rarity, count: count, total: total)
        }
      }
    }
    .padding(20)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(16)
  }

  private func rarityBadge(rarity: AchievementRarity, count: Int, total: Int) -> some View {
    VStack(spacing: 4) {
      Text("\(count)/\(total)")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(rarity.color)
      Text(rarity.label)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(rarity.color.opacity(0.1))
    .cornerRadius(8)
  }
}

// MARK: - AchievementCell

struct AchievementCell: View {
  let achievement: Achievement

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(achievement.isUnlocked
                ? achievement.rarity.color.opacity(0.15)
                : Color(.systemFill))
          .frame(width: 56, height: 56)

        Image(systemName: achievement.iconName)
          .font(.system(size: 24))
          .foregroundStyle(achievement.isUnlocked
                           ? achievement.rarity.color
                           : Color(.systemGray3))

        if !achievement.isUnlocked {
          Image(systemName: "lock.fill")
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .padding(4)
            .background(Color(.systemGray2))
            .clipShape(Circle())
            .offset(x: 18, y: 18)
        }
      }

      Text(achievement.isUnlocked ? achievement.title : "???")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)

      if achievement.isUnlocked {
        Text(achievement.rarity.label)
          .font(.system(size: 10))
          .foregroundStyle(achievement.rarity.color)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(achievement.rarity.color.opacity(0.15))
          .cornerRadius(4)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(achievement.isUnlocked ? achievement.rarity.color.opacity(0.3) : Color.clear, lineWidth: 1)
    )
  }
}

// MARK: - AchievementUnlockOverlay

/// 解鎖新成就時顯示的全畫面動畫 overlay
struct AchievementUnlockOverlay: View {
  let achievement: Achievement
  let onDismiss: () -> Void

  @State private var scale: CGFloat = 0.5
  @State private var opacity: Double = 0

  var body: some View {
    ZStack {
      Color.black.opacity(0.5)
        .ignoresSafeArea()
        .onTapGesture { dismiss() }

      VStack(spacing: 20) {
        Text("🎉 成就解鎖！")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white.opacity(0.9))

        ZStack {
          Circle()
            .fill(achievement.rarity.color.opacity(0.25))
            .frame(width: 100, height: 100)
          Circle()
            .fill(achievement.rarity.color.opacity(0.15))
            .frame(width: 120, height: 120)
          Image(systemName: achievement.iconName)
            .font(.system(size: 44))
            .foregroundStyle(achievement.rarity.color)
        }

        VStack(spacing: 6) {
          Text(achievement.title)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.white)
          Text(achievement.description)
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.8))
          Text(achievement.rarity.label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(achievement.rarity.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(achievement.rarity.color.opacity(0.2))
            .cornerRadius(8)
        }

        Button(action: dismiss) {
          Text("太棒了！")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(achievement.rarity.color)
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
      }
      .padding(32)
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(Color(.systemBackground).opacity(0.15))
          .background(.ultraThinMaterial)
          .cornerRadius(24)
      )
      .padding(.horizontal, 32)
      .scaleEffect(scale)
      .opacity(opacity)
    }
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        scale = 1.0
        opacity = 1.0
      }
    }
  }

  private func dismiss() {
    withAnimation(.easeOut(duration: 0.2)) {
      opacity = 0
      scale = 0.85
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
  }
}
