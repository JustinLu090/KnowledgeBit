// AchievementService.swift
// 成就系統：定義成就目錄、追蹤進度、解鎖與通知

import Foundation
import SwiftUI
import Combine

// MARK: - Achievement Model

enum AchievementRarity: String, Codable, CaseIterable {
  case common, rare, epic, legendary

  var label: String {
    switch self {
    case .common:    return "普通"
    case .rare:      return "稀有"
    case .epic:      return "史詩"
    case .legendary: return "傳說"
    }
  }

  var color: Color {
    switch self {
    case .common:    return .blue
    case .rare:      return .green
    case .epic:      return .purple
    case .legendary: return .orange
    }
  }
}

struct Achievement: Identifiable, Codable {
  let id: String
  let title: String
  let description: String
  let iconName: String
  let rarity: AchievementRarity
  var unlockedAt: Date?

  var isUnlocked: Bool { unlockedAt != nil }
}

// MARK: - AchievementService

final class AchievementService: ObservableObject {
  static let shared = AchievementService()

  @Published private(set) var achievements: [Achievement] = []
  /// 最新解鎖的成就（用於顯示 overlay 動畫）
  @Published private(set) var newlyUnlocked: Achievement?

  // MARK: UserDefaults keys
  private let unlockedIdsKey      = "achievement_unlocked_ids"
  private let unlockedDatesKey    = "achievement_unlocked_dates"
  let totalQuizzesKey    = "achievement_total_quizzes"
  let totalReviewsKey    = "achievement_total_reviews"
  let totalBattleWinsKey = "achievement_total_battle_wins"
  let totalDailyQuestsKey = "achievement_total_daily_quests"
  let totalFriendsKey    = "achievement_total_friends"

  private let defaults: UserDefaults

  // MARK: - Achievement Catalog

  static let catalog: [Achievement] = [
    // Level 成就
    Achievement(id: "level_5",  title: "知識新秀", description: "達到等級 5",  iconName: "star.fill",  rarity: .common),
    Achievement(id: "level_10", title: "知識達人", description: "達到等級 10", iconName: "star.fill",  rarity: .rare),
    Achievement(id: "level_20", title: "知識宗師", description: "達到等級 20", iconName: "crown.fill", rarity: .epic),
    Achievement(id: "level_50", title: "知識傳說", description: "達到等級 50", iconName: "crown.fill", rarity: .legendary),

    // Streak 成就
    Achievement(id: "streak_3",  title: "三日不輟",   description: "連續學習 3 天",  iconName: "flame.fill", rarity: .common),
    Achievement(id: "streak_7",  title: "一週堅持",   description: "連續學習 7 天",  iconName: "flame.fill", rarity: .rare),
    Achievement(id: "streak_30", title: "一月不間斷", description: "連續學習 30 天", iconName: "flame.fill", rarity: .legendary),

    // 測驗成就
    Achievement(id: "quiz_10", title: "測驗初心", description: "完成 10 次測驗", iconName: "checkmark.circle.fill", rarity: .common),
    Achievement(id: "quiz_50", title: "測驗達人", description: "完成 50 次測驗", iconName: "checkmark.circle.fill", rarity: .rare),

    // 複習成就
    Achievement(id: "review_100", title: "百張達人",  description: "累積複習 100 張卡片", iconName: "book.fill", rarity: .common),
    Achievement(id: "review_500", title: "五百張勇者", description: "累積複習 500 張卡片", iconName: "book.fill", rarity: .epic),

    // 對戰成就
    Achievement(id: "battle_win_1",  title: "初露鋒芒", description: "贏得第一場對戰",    iconName: "bolt.fill", rarity: .common),
    Achievement(id: "battle_win_10", title: "戰鬥達人", description: "贏得 10 場對戰", iconName: "bolt.fill", rarity: .rare),

    // 社交成就
    Achievement(id: "friend_1", title: "結交好友", description: "加入第一位好友", iconName: "person.2.fill", rarity: .common),

    // 每日任務成就
    Achievement(id: "daily_quest_10", title: "任務狂",  description: "完成 10 個每日任務", iconName: "list.bullet.circle.fill", rarity: .rare),
    Achievement(id: "daily_quest_30", title: "每日勇者", description: "完成 30 個每日任務", iconName: "list.bullet.circle.fill", rarity: .epic),
  ]

  /// 各成就 id 是否達成門檻（與 `evaluate` 邏輯一致，供單元測試直接驗證）
  static func achievementConditions(
    level: Int,
    streak: Int,
    quizzes: Int,
    reviews: Int,
    battles: Int,
    quests: Int,
    friends: Int
  ) -> [String: Bool] {
    [
      "level_5": level >= 5,
      "level_10": level >= 10,
      "level_20": level >= 20,
      "level_50": level >= 50,
      "streak_3": streak >= 3,
      "streak_7": streak >= 7,
      "streak_30": streak >= 30,
      "quiz_10": quizzes >= 10,
      "quiz_50": quizzes >= 50,
      "review_100": reviews >= 100,
      "review_500": reviews >= 500,
      "battle_win_1": battles >= 1,
      "battle_win_10": battles >= 10,
      "friend_1": friends >= 1,
      "daily_quest_10": quests >= 10,
      "daily_quest_30": quests >= 30,
    ]
  }

  // MARK: - Init

  private init() {
    defaults = AppGroup.sharedUserDefaults() ?? .standard
    reload()
  }

  // MARK: - Load / Save

  private func reload() {
    let unlockedIds = defaults.stringArray(forKey: unlockedIdsKey) ?? []
    var unlockedDates: [String: Date] = [:]
    if let data = defaults.data(forKey: unlockedDatesKey),
       let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
      unlockedDates = decoded
    }
    achievements = Self.catalog.map { a in
      var copy = a
      if unlockedIds.contains(a.id) {
        copy.unlockedAt = unlockedDates[a.id] ?? Date()
      }
      return copy
    }
  }

  private func persist(unlockedIds: [String], dates: [String: Date]) {
    defaults.set(unlockedIds, forKey: unlockedIdsKey)
    if let data = try? JSONEncoder().encode(dates) {
      defaults.set(data, forKey: unlockedDatesKey)
    }
  }

  // MARK: - Counter Increments (call at trigger points)

  func recordQuizCompleted() {
    defaults.set(defaults.integer(forKey: totalQuizzesKey) + 1, forKey: totalQuizzesKey)
  }

  func recordReviewCompleted(count: Int = 1) {
    defaults.set(defaults.integer(forKey: totalReviewsKey) + count, forKey: totalReviewsKey)
  }

  func recordBattleWin() {
    defaults.set(defaults.integer(forKey: totalBattleWinsKey) + 1, forKey: totalBattleWinsKey)
  }

  func recordDailyQuestCompleted() {
    defaults.set(defaults.integer(forKey: totalDailyQuestsKey) + 1, forKey: totalDailyQuestsKey)
  }

  func recordFriendCount(_ count: Int) {
    defaults.set(count, forKey: totalFriendsKey)
  }

  // MARK: - Evaluate

  /// 根據當前數據評估所有成就，解鎖符合條件者。可在任何時機呼叫。
  @MainActor
  func evaluate(level: Int, streak: Int) {
    let quizzes    = defaults.integer(forKey: totalQuizzesKey)
    let reviews    = defaults.integer(forKey: totalReviewsKey)
    let battles    = defaults.integer(forKey: totalBattleWinsKey)
    let quests     = defaults.integer(forKey: totalDailyQuestsKey)
    let friends    = defaults.integer(forKey: totalFriendsKey)

    let conditions = Self.achievementConditions(
      level: level,
      streak: streak,
      quizzes: quizzes,
      reviews: reviews,
      battles: battles,
      quests: quests,
      friends: friends
    )

    var unlockedIds = defaults.stringArray(forKey: unlockedIdsKey) ?? []
    var dates: [String: Date] = [:]
    if let data = defaults.data(forKey: unlockedDatesKey),
       let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
      dates = decoded
    }

    var newOnes: [Achievement] = []
    for (id, met) in conditions {
      guard met, !unlockedIds.contains(id) else { continue }
      unlockedIds.append(id)
      dates[id] = Date()
      if let a = Self.catalog.first(where: { $0.id == id }) { newOnes.append(a) }
    }

    guard !newOnes.isEmpty else { return }
    persist(unlockedIds: unlockedIds, dates: dates)
    reload()
    // 依稀有度排序，優先展示最稀有的成就
    newlyUnlocked = newOnes.sorted { $0.rarity.rawValue > $1.rarity.rawValue }.first
  }

  func dismissNewlyUnlocked() {
    newlyUnlocked = nil
  }

  // MARK: - Stats helpers

  var unlockedCount: Int { achievements.filter(\.isUnlocked).count }
  var totalCount: Int    { achievements.count }
}
