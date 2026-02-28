import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import Foundation

// MARK: - AppGroup (Widget Extension 本地定義)
// 注意：如果 AppGroup.swift 已添加到 Widget Extension target，可以移除此定義
enum AppGroup {
  /// App Group identifier for sharing SwiftData container between main app and widget
  static let identifier = "group.com.team.knowledgebit"
  
  /// 取得 App Group 共用的 UserDefaults。
  /// 讀寫請在主線程執行，以避免 CFPrefsPlistSource 相關錯誤。
  static func sharedUserDefaults() -> UserDefaults? {
    UserDefaults(suiteName: identifier)
  }
  
  // MARK: - UserDefaults Keys
  
  /// UserDefaults Key 常數定義（避免硬編碼字串）
  enum Keys {
    // 用戶資料
    static let displayName = "appgroup_user_display_name"
    static let avatarURL = "appgroup_user_avatar_url"
    static let userId = "appgroup_user_id"
    
    // 經驗值與等級
    static let level = "userLevel"
    static let exp = "userExp"
    static let expToNext = "expToNext"
    
    // Widget 相關
    static let todayDueCount = "today_due_count"
    static let widgetWordSetId = "widget_word_set_id"

    // 對戰地圖 Widget 快照
    static let widgetBattleWordSetId = "widget_battle_word_set_id"
    static let widgetBattleRoomId = "widget_battle_room_id"
    static let widgetBattleWordSetTitle = "widget_battle_word_set_title"
    static let widgetBattleCells = "widget_battle_cells"
    static let widgetBattleCreatorId = "widget_battle_creator_id"
    static let widgetBattleCurrentUserId = "widget_battle_current_user_id"
    static let widgetBattleUpdatedAt = "widget_battle_updated_at"
  }

  // MARK: - Supabase 欄位名稱
  
  /// Supabase 資料庫欄位名稱常數定義（避免硬編碼字串）
  enum SupabaseFields {
    static let displayName = "display_name"
    static let currentExp = "current_exp"
    static let avatarURL = "avatar_url"
    static let userId = "user_id"
    static let level = "level"
    static let updatedAt = "updated_at"
  }
}

// MARK: - WordSet Forward Declaration（需與主 App WordSet 欄位一致，否則 App Group 共用 store 會 schema 不符）
@Model
final class WordSet {
  @Attribute(.unique) var id: UUID
  var title: String
  var level: String?
  var createdAt: Date
  var ownerUserId: UUID?
  @Relationship(deleteRule: .cascade, inverse: \Card.wordSet) var cards: [Card] = []

  init() {
    self.id = UUID()
    self.title = ""
    self.level = nil
    self.createdAt = Date()
    self.ownerUserId = nil
    self.cards = []
  }
}

// MARK: - DailyStats Forward Declaration（與主 App schema 一致，共用 store 時必要）
@Model
final class DailyStats {
  var date: Date
  var expGained: Int
  var studyMinutes: Int

  init(date: Date, expGained: Int = 0, studyMinutes: Int = 0) {
    self.date = date
    self.expGained = expGained
    self.studyMinutes = studyMinutes
  }
}

// MARK: - UserProfile Forward Declaration
@Model
final class UserProfile {
  @Attribute(.unique) var userId: UUID
  var displayName: String
  var avatarData: Data?  // 頭貼圖片資料（儲存在資料庫中）
  var avatarURL: String?  // Google 頭貼 URL（僅用於遠端載入）
  var level: Int  // 用戶等級
  var currentExp: Int  // 當前經驗值
  var updatedAt: Date
  
  init(userId: UUID, displayName: String = "使用者", avatarData: Data? = nil, avatarURL: String? = nil, level: Int = 1, currentExp: Int = 0) {
    self.userId = userId
    self.displayName = displayName
    self.avatarData = avatarData
    self.avatarURL = avatarURL
    self.level = level
    self.currentExp = currentExp
    self.updatedAt = Date()
  }
}

// MARK: - App Group Configuration
// 使用統一的 App Group identifier（與主 App 的 AppGroup.identifier 一致）
// 注意：Widget Extension 需要能夠訪問 AppGroup.swift，確保該文件在 Widget target 中
private let sharedAppGroupIdentifier = AppGroup.identifier

// MARK: - Shared SwiftData Container
enum KnowledgeBitSharedContainer {
  static let appGroupIdentifier = sharedAppGroupIdentifier

  static var container: ModelContainer? = {
    let schema = Schema([
      Card.self,
      StudyLog.self,
      DailyStats.self,
      WordSet.self,
      UserProfile.self
    ])

    guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      print("⚠️ Widget: App Group not available")
      return nil
    }
    
    // 確保 Application Support 目錄存在
    let appSupportURL = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
    let fileManager = FileManager.default
    
    if !fileManager.fileExists(atPath: appSupportURL.path) {
      do {
        try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        print("✅ Widget: Created Application Support directory")
      } catch {
        print("⚠️ Widget: Failed to create Application Support directory: \(error.localizedDescription)")
      }
    }

    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      groupContainer: .identifier(appGroupIdentifier)
    )

    do {
      let container = try ModelContainer(for: schema, configurations: [configuration])
      return container
    } catch {
      print("❌ Widget: Failed to create ModelContainer: \(error.localizedDescription)")
      return nil
    }
  }()

  @MainActor
  static func fetchAllCards() -> [Card] {
    guard let container = container else { return [] }
    let context = container.mainContext
    let descriptor = FetchDescriptor<Card>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
    do {
      return try context.fetch(descriptor)
    } catch {
      return []
    }
  }

  /// 取得指定單字集內所有卡片，固定依 createdAt 排序（與主 App 一致，同單字集使用者輪播一致）
  @MainActor
  static func fetchCardsForWordSet(wordSetId: UUID) -> [Card] {
    guard let container = container else { return [] }
    let context = container.mainContext
    let descriptor = FetchDescriptor<Card>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
    do {
      let all = try context.fetch(descriptor)
      return all.filter { $0.wordSet?.id == wordSetId }
    } catch {
      return []
    }
  }

  /// 取得第一個單字集的 ID（widget 未設定單字集時的 fallback）
  @MainActor
  static func fetchFirstWordSetId() -> UUID? {
    guard let container = container else { return nil }
    let context = container.mainContext
    var descriptor = FetchDescriptor<WordSet>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
    descriptor.fetchLimit = 1
    do {
      let results = try context.fetch(descriptor)
      return results.first?.id
    } catch {
      return nil
    }
  }

  @MainActor
  static func selectCardsForWidget(from allCards: [Card]) -> [Card] {
    if allCards.count <= 5 {
      return allCards
    } else {
      return Array(allCards.shuffled().prefix(5))
    }
  }

  @MainActor
  static func fetchCardsByIDs(_ cardIDs: [String]) -> [Card] {
    guard let container = container else { return [] }
    let context = container.mainContext
    let descriptor = FetchDescriptor<Card>()
    do {
      let allCards = try context.fetch(descriptor)
      return allCards.filter { cardIDs.contains($0.id.uuidString) }
    } catch {
      return []
    }
  }
}

// MARK: - Time-based slot for same word set sync (15 min per batch, 5 cards per batch)
private enum WidgetTimeSlot {
  static let intervalMinutes = 15
  static let batchSize = 5

  /// 依當前時間計算 slot 索引，使同單字集使用者在同一時區看到同一批 5 張
  static func slotIndex(at date: Date) -> Int {
    let ref = Date(timeIntervalSince1970: 0)
    let totalMinutes = Int(date.timeIntervalSince(ref) / 60)
    return totalMinutes / intervalMinutes
  }

  /// 從已排序的卡片陣列取出「當前 15 分鐘 slot」對應的那一批（最多 5 張）
  static func currentBatch(from sortedCards: [Card], at date: Date) -> [Card] {
    guard !sortedCards.isEmpty else { return [] }
    let batches = max(1, (sortedCards.count + batchSize - 1) / batchSize)
    let slot = slotIndex(at: date) % batches
    let start = slot * batchSize
    let end = min(start + batchSize, sortedCards.count)
    guard start < end else { return Array(sortedCards.prefix(batchSize)) }
    return Array(sortedCards[start..<end])
  }
}

// MARK: - Card Index Storage
struct CardIndexStore {
  private static let defaults = UserDefaults(suiteName: sharedAppGroupIdentifier)
  private static let currentIndexKey = "widget.currentCardIndex"
  private static let selectedCardIDsKey = "widget.selectedCardIDs"

  static func getCurrentIndex() -> Int {
    return defaults?.integer(forKey: currentIndexKey) ?? 0
  }

  static func setCurrentIndex(_ index: Int) {
    defaults?.set(index, forKey: currentIndexKey)
    defaults?.synchronize()
  }

  static func getSelectedCardIDs() -> [String] {
    return defaults?.stringArray(forKey: selectedCardIDsKey) ?? []
  }

  static func setSelectedCardIDs(_ ids: [String]) {
    defaults?.set(ids, forKey: selectedCardIDsKey)
    defaults?.synchronize()
  }

  static func clampIndex(_ index: Int, cardCount: Int) -> Int {
    guard cardCount > 0 else { return 0 }
    if index < 0 { return cardCount - 1 }
    else if index >= cardCount { return 0 }
    return index
  }

  static func nextIndex(cardCount: Int) -> Int {
    guard cardCount > 0 else { return 0 }
    let current = getCurrentIndex()
    let next = (current + 1) % cardCount
    setCurrentIndex(next)
    return next
  }

  static func previousIndex(cardCount: Int) -> Int {
    guard cardCount > 0 else { return 0 }
    let current = getCurrentIndex()
    let previous = current - 1 < 0 ? cardCount - 1 : current - 1
    setCurrentIndex(previous)
    return previous
  }
}

// MARK: - App Intents
struct NextCardIntent: AppIntent {
  static var title: LocalizedStringResource = "下一張卡片"
  static var description = IntentDescription("切換到下一張知識卡片")

  func perform() async throws -> some IntentResult {
    let storedCardIDs = CardIndexStore.getSelectedCardIDs()
    guard !storedCardIDs.isEmpty else {
      WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      return .result()
    }

    let cards = await KnowledgeBitSharedContainer.fetchCardsByIDs(storedCardIDs)
    guard !cards.isEmpty else {
      WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      return .result()
    }

    let _ = CardIndexStore.nextIndex(cardCount: cards.count)
    WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
    return .result()
  }
}

struct PreviousCardIntent: AppIntent {
  static var title: LocalizedStringResource = "上一張卡片"
  static var description = IntentDescription("切換到上一張知識卡片")

  func perform() async throws -> some IntentResult {
    let storedCardIDs = CardIndexStore.getSelectedCardIDs()
    guard !storedCardIDs.isEmpty else {
      WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      return .result()
    }

    let cards = await KnowledgeBitSharedContainer.fetchCardsByIDs(storedCardIDs)
    guard !cards.isEmpty else {
      WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      return .result()
    }

    let _ = CardIndexStore.previousIndex(cardCount: cards.count)
    WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
    return .result()
  }
}

// MARK: - Configuration Intent
struct ConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "知識小工具"
  static var description = IntentDescription("顯示知識卡片")
}

// MARK: - Timeline Entry
struct CardEntry: TimelineEntry {
  let date: Date
  let cards: [Card]
  let cardIndex: Int
  let cardIDs: [String]
  let todoCount: Int // 新增：用於鎖定畫面顯示剩餘張數
  let todayDueCount: Int // 今日到期複習卡片數

  var currentCard: Card? {
    guard cardIndex >= 0 && cardIndex < cards.count else { return nil }
    return cards[cardIndex]
  }

  var totalCards: Int {
    cards.count
  }

  // 初始化：一般情況
  init(cards: [Card], index: Int, cardIDs: [String], date: Date = Date(), todayDueCount: Int = 0) {
    self.date = date
    self.cards = cards
    self.cardIndex = index
    self.cardIDs = cardIDs
    self.todoCount = cards.count // 簡單起見，這裡用本次輪播的總張數當作待辦數
    self.todayDueCount = todayDueCount
  }

  // 初始化：Placeholder（用於第一次啟動或資料不可用時）
  // 所有值都使用安全的預設值，避免 Widget 顯示空白或崩潰
  init() {
    self.date = Date()
    self.cards = []
    self.cardIndex = 0
    self.cardIDs = []
    self.todoCount = 0
    self.todayDueCount = 0
    // 注意：displayName、level、exp 等資料會在 Widget View 中透過 getUserProfile() 讀取
    // 如果讀不到，會使用預設值（"使用者", Level 1, EXP 0）
  }
}

// MARK: - Timeline Provider
struct CardTimelineProvider: AppIntentTimelineProvider {
  typealias Intent = ConfigurationAppIntent
  typealias Entry = CardEntry

  /// 從 App Group 讀取 Widget 要顯示的單字集 ID；若無則用第一個單字集
  private func getWidgetWordSetId() -> UUID? {
    guard let defaults = AppGroup.sharedUserDefaults() else { return nil }
    guard let raw = defaults.string(forKey: AppGroup.Keys.widgetWordSetId), !raw.isEmpty else { return nil }
    return UUID(uuidString: raw)
  }

  func placeholder(in context: Context) -> CardEntry {
    let placeholderCard = Card(title: "TCP Handshake", content: "定義\n\n建立連線的三向交握過程...", wordSet: nil)
    let cardIDs = [placeholderCard.id.uuidString]
    return CardEntry(cards: [placeholderCard], index: 0, cardIDs: cardIDs, todayDueCount: 0)
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> CardEntry {
    var wordSetId = getWidgetWordSetId()
    if wordSetId == nil {
      wordSetId = await KnowledgeBitSharedContainer.fetchFirstWordSetId()
    }
    let now = Date()

    if let wid = wordSetId {
      let allInSet = await KnowledgeBitSharedContainer.fetchCardsForWordSet(wordSetId: wid)
      let batch = WidgetTimeSlot.currentBatch(from: allInSet, at: now)
      if !batch.isEmpty {
        let cardIDs = batch.map { $0.id.uuidString }
        CardIndexStore.setSelectedCardIDs(cardIDs)
        let idx = CardIndexStore.clampIndex(CardIndexStore.getCurrentIndex(), cardCount: batch.count)
        if idx != CardIndexStore.getCurrentIndex() { CardIndexStore.setCurrentIndex(idx) }
        return CardEntry(cards: batch, index: idx, cardIDs: cardIDs, todayDueCount: 0)
      }
    }

    // Fallback: 無單字集或該集無卡片，用全部卡片取前 5 張
    let allCards = await KnowledgeBitSharedContainer.fetchAllCards()
    if allCards.isEmpty { return CardEntry() }
    let fallback = allCards.count <= 5 ? allCards : Array(allCards.prefix(5))
    let cardIDs = fallback.map { $0.id.uuidString }
    CardIndexStore.setSelectedCardIDs(cardIDs)
    let idx = CardIndexStore.clampIndex(CardIndexStore.getCurrentIndex(), cardCount: fallback.count)
    return CardEntry(cards: fallback, index: idx, cardIDs: cardIDs, todayDueCount: 0)
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<CardEntry> {
    var wordSetId = getWidgetWordSetId()
    if wordSetId == nil {
      wordSetId = await KnowledgeBitSharedContainer.fetchFirstWordSetId()
    }
    let now = Date()

    if let wid = wordSetId {
      let allInSet = await KnowledgeBitSharedContainer.fetchCardsForWordSet(wordSetId: wid)
      if !allInSet.isEmpty {
        let batch = WidgetTimeSlot.currentBatch(from: allInSet, at: now)
        if !batch.isEmpty {
          let cardIDs = batch.map { $0.id.uuidString }
          CardIndexStore.setSelectedCardIDs(cardIDs)
          let validIndex = CardIndexStore.clampIndex(CardIndexStore.getCurrentIndex(), cardCount: batch.count)
          if validIndex != CardIndexStore.getCurrentIndex() { CardIndexStore.setCurrentIndex(validIndex) }

          let entry = CardEntry(cards: batch, index: validIndex, cardIDs: cardIDs, date: now, todayDueCount: 0)
          let nextRefresh = Calendar.current.date(byAdding: .minute, value: WidgetTimeSlot.intervalMinutes, to: now)!
          return Timeline(entries: [entry], policy: .after(nextRefresh))
        }
      }
    }

    // Fallback: 無單字集或該集無卡片
    let allCards = await KnowledgeBitSharedContainer.fetchAllCards()
    if allCards.isEmpty {
      let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
      return Timeline(entries: [CardEntry()], policy: .after(nextUpdate))
    }
    let fallback = allCards.count <= 5 ? allCards : Array(allCards.prefix(5))
    let cardIDs = fallback.map { $0.id.uuidString }
    CardIndexStore.setSelectedCardIDs(cardIDs)
    let validIndex = CardIndexStore.clampIndex(CardIndexStore.getCurrentIndex(), cardCount: fallback.count)
    let entry = CardEntry(cards: fallback, index: validIndex, cardIDs: cardIDs, date: now, todayDueCount: 0)
    let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
    return Timeline(entries: [entry], policy: .after(nextRefresh))
  }
}

// MARK: - Definition line from card content (same logic as MultipleChoiceQuizView)
private func definitionLine(from content: String) -> String {
  let normalized = content
    .replacingOccurrences(of: "\r", with: "")
    .components(separatedBy: "\n")
  let set = CharacterSet.whitespacesAndNewlines
  if let defIndex = normalized.firstIndex(where: { $0.trimmingCharacters(in: set) == "定義" }) {
    let nextSlice = normalized.suffix(from: normalized.index(after: defIndex))
    if let line = nextSlice.first(where: { !$0.trimmingCharacters(in: set).isEmpty }) {
      return line.trimmingCharacters(in: set)
    }
  }
  if let first = normalized.first(where: {
    let t = $0.trimmingCharacters(in: set)
    return !t.isEmpty && t != "定義" && t != "例句"
  }) {
    return first.trimmingCharacters(in: set)
  }
  return ""
}

/// 從卡片內容擷取「例句」那一行（長方形 widget 底下補充說明用）
private func exampleLine(from content: String) -> String {
  let normalized = content
    .replacingOccurrences(of: "\r", with: "")
    .components(separatedBy: "\n")
  let set = CharacterSet.whitespacesAndNewlines
  if let exIndex = normalized.firstIndex(where: { $0.trimmingCharacters(in: set) == "例句" }) {
    let nextSlice = normalized.suffix(from: normalized.index(after: exIndex))
    if let line = nextSlice.first(where: { !$0.trimmingCharacters(in: set).isEmpty }) {
      return line.trimmingCharacters(in: set)
    }
  }
  return ""
}

// MARK: - Widget View

struct KnowledgeWidgetEntryView: View {
  var entry: CardEntry

  // 1. 抓取環境變數，判斷是「桌面」還是「鎖定畫面」
  @Environment(\.widgetFamily) var family

  var body: some View {
    switch family {

      // --- A. 鎖定畫面：圓形小工具 (顯示進度) ---
    case .accessoryCircular:
      ZStack {
        // 背景圓圈
        Circle()
          .stroke(lineWidth: 4)
          .opacity(0.3)

        // 進度圓圈 (模擬顯示本次輪播的進度，這裡用 index/total 計算)
        let progress = entry.totalCards > 0 ? Double(entry.cardIndex + 1) / Double(entry.totalCards) : 0
        Circle()
          .trim(from: 0.0, to: progress)
          .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .foregroundStyle(.white)

        // 中間數字
        VStack(spacing: 0) {
          Text("\(entry.totalCards)")
            .font(.system(size: 14, weight: .bold))
          Text("CARDS")
            .font(.system(size: 7))
        }
      }
      .containerBackground(.fill.tertiary, for: .widget)

      // --- B. 鎖定畫面：矩形小工具 (顯示單字與解釋) ---
    case .accessoryRectangular:
      if let card = entry.currentCard {
        let def = definitionLine(from: card.content)
        VStack(alignment: .leading, spacing: 2) {
          Text(card.title)
            .font(.headline)
            .bold()
            .lineLimit(1)
          Text(def.isEmpty ? "定義..." : def)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
      } else {
        Text("No Cards")
          .containerBackground(.fill.tertiary, for: .widget)
      }

      // --- C. 鎖定畫面：上方文字列 (日期旁邊) ---
    case .accessoryInline:
      if let card = entry.currentCard {
        Text("🧠 \(card.title)")
      } else {
        Text("KnowledgeBit")
      }

      // --- D. 桌面小工具 (保留原本的完整 UI) ---
    case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
      VStack(spacing: 0) {
        // Top row
        HStack {
          if let card = entry.currentCard, let wordSetTitle = card.wordSet?.title {
            Text(wordSetTitle)
              .font(.caption2)
              .fontWeight(.bold)
              .foregroundStyle(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.blue.opacity(0.8))
              .cornerRadius(4)
          } else {
            Text("單字集")
              .font(.caption2)
              .fontWeight(.bold)
              .foregroundStyle(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.gray.opacity(0.8))
              .cornerRadius(4)
          }
          Spacer()
        }
        .padding(.bottom, 8)

        // Main content：小正方形用直式避免卡字，長方形用橫式＋底下補充例句
        if let card = entry.currentCard {
          let def = definitionLine(from: card.content)
          let example = exampleLine(from: card.content)
          Link(destination: URL(string: "knowledgebit://card?id=\(card.title)")!) {
            if family == .systemSmall {
              VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                  .font(.headline)
                  .fontWeight(.bold)
                  .lineLimit(1)
                  .minimumScaleFactor(0.8)
                  .frame(maxWidth: .infinity, alignment: .leading)
                Text(def.isEmpty ? "定義..." : def)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            } else {
              VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 16) {
                  Text(card.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  Text(def.isEmpty ? "定義..." : def)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !example.isEmpty {
                  Text(example)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
            }
          }
        } else {
          VStack(alignment: .leading, spacing: 4) {
            Text("尚無卡片")
              .font(.headline)
              .bold()
              .frame(maxWidth: .infinity, alignment: .leading)
            Text("請先進入 App 新增知識卡片")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        Spacer(minLength: 12)

        Divider()
          .opacity(0.4)

        // Bottom row with buttons
        HStack {
          if entry.totalCards > 0 {
            Button(intent: PreviousCardIntent()) {
              Image(systemName: "arrow.left.circle.fill")
                .font(.title2)
                .foregroundStyle(entry.totalCards > 1 ? Color.blue : Color.gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(entry.totalCards <= 1)
          } else {
            Image(systemName: "arrow.left.circle.fill")
              .font(.title2)
              .foregroundStyle(Color.gray.opacity(0.3))
          }

          Spacer()

          // Dots
          if entry.totalCards > 0 {
            let currentIndex = entry.cardIndex
            HStack(spacing: 4) {
              ForEach(0..<entry.totalCards, id: \.self) { index in
                Circle()
                  .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                  .frame(width: 4, height: 4)
              }
            }
          }

          Spacer()

          if entry.totalCards > 0 {
            Button(intent: NextCardIntent()) {
              Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(entry.totalCards > 1 ? Color.blue : Color.gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(entry.totalCards <= 1)
          } else {
            Image(systemName: "arrow.right.circle.fill")
              .font(.title2)
              .foregroundStyle(Color.gray.opacity(0.3))
          }
        }
        .padding(.top, 8)
      }
      .padding()
      .containerBackground(for: .widget) {
        Color(UIColor.systemBackground)
      }

    @unknown default:
      Text("Unsupported")
    }
  }
}

// MARK: - Battle Map Widget

struct BattleMapCellSnapshot: Codable {
  let id: Int
  let owner: String
  let hp_now: Int
  let hp_max: Int
}

struct BattleMapEntry: TimelineEntry {
  let date: Date
  let wordSetId: UUID?
  let roomId: UUID?
  let wordSetTitle: String?
  let cells: [BattleMapCellSnapshot]
  let creatorId: UUID?
  let currentUserId: UUID?
}

struct BattleMapTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> BattleMapEntry {
    BattleMapEntry(date: Date(), wordSetId: nil, roomId: nil, wordSetTitle: nil, cells: [], creatorId: nil, currentUserId: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (BattleMapEntry) -> Void) {
    completion(readSnapshot())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BattleMapEntry>) -> Void) {
    let entry = readSnapshot()
    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
    completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
  }

  private func readSnapshot() -> BattleMapEntry {
    guard let defaults = AppGroup.sharedUserDefaults() else {
      return BattleMapEntry(date: Date(), wordSetId: nil, roomId: nil, wordSetTitle: nil, cells: [], creatorId: nil, currentUserId: nil)
    }
    let wordSetIdStr = defaults.string(forKey: AppGroup.Keys.widgetBattleWordSetId)
    let roomIdStr = defaults.string(forKey: AppGroup.Keys.widgetBattleRoomId)
    let wordSetTitle = defaults.string(forKey: AppGroup.Keys.widgetBattleWordSetTitle)
    let creatorIdStr = defaults.string(forKey: AppGroup.Keys.widgetBattleCreatorId)
    let currentUserIdStr = defaults.string(forKey: AppGroup.Keys.widgetBattleCurrentUserId)
    let cellsJson = defaults.string(forKey: AppGroup.Keys.widgetBattleCells)

    let wordSetId = wordSetIdStr.flatMap { UUID(uuidString: $0) }
    let roomId = roomIdStr.flatMap { UUID(uuidString: $0) }
    let creatorId = creatorIdStr.flatMap { UUID(uuidString: $0) }
    let currentUserId = currentUserIdStr.flatMap { UUID(uuidString: $0) }

    var cells: [BattleMapCellSnapshot] = []
    if let json = cellsJson?.data(using: .utf8),
       let decoded = try? JSONDecoder().decode([BattleMapCellSnapshot].self, from: json), decoded.count == 16 {
      cells = decoded
    }

    return BattleMapEntry(
      date: Date(),
      wordSetId: wordSetId,
      roomId: roomId,
      wordSetTitle: wordSetTitle,
      cells: cells,
      creatorId: creatorId,
      currentUserId: currentUserId
    )
  }
}

struct BattleMapEntryView: View {
  var entry: BattleMapEntry
  @Environment(\.widgetFamily) var family

  private var isRedTeam: Bool {
    guard let cid = entry.creatorId, let me = entry.currentUserId else { return false }
    return me != cid
  }

  /// 是否有足夠資訊顯示「您的隊伍」（有 creator + currentUser 才顯示）
  private var canShowTeam: Bool {
    entry.creatorId != nil && entry.currentUserId != nil
  }

  private var myTeamLabel: String {
    isRedTeam ? "紅隊" : "藍隊"
  }

  private var myTeamColor: Color {
    isRedTeam ? Color.red : Color.blue
  }

  private func color(for owner: String) -> Color {
    switch owner {
    case "player": return isRedTeam ? Color.red : Color.blue
    case "enemy": return isRedTeam ? Color.blue : Color.red
    default: return Color(.systemGray4)
    }
  }

  var body: some View {
    let hasData = entry.cells.count == 16, wordSetId = entry.wordSetId ?? UUID()
    let title = (entry.wordSetTitle?.isEmpty == false) ? entry.wordSetTitle! : "對戰地圖"
    let url = URL(string: "knowledgebit://battle?wordSetId=\(wordSetId.uuidString)")!

    Link(destination: url) {
      VStack(alignment: .leading, spacing: 6) {
        // 標題與「您的隊伍」同一行，省出垂直空間給地圖
        HStack(alignment: .center, spacing: 8) {
          Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
          if canShowTeam {
            HStack(spacing: 4) {
              Text("您的隊伍")
                .font(.caption)
                .foregroundStyle(.secondary)
              Text(myTeamLabel)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(myTeamColor, in: Capsule())
            }
          }
          Spacer(minLength: 0)
        }

        if hasData {
          let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 4)
          LazyVGrid(columns: columns, spacing: 3) {
            ForEach(entry.cells.sorted(by: { $0.id < $1.id }), id: \.id) { cell in
              RoundedRectangle(cornerRadius: 6)
                .fill(color(for: cell.owner))
                .overlay(
                  RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .aspectRatio(1, contentMode: .fit)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .aspectRatio(1, contentMode: .fit)
        } else {
          Spacer()
          Text("請在 App 中進入對戰以顯示地圖")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
          Spacer()
        }

        Spacer(minLength: 0)
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
  }
}

struct BattleMapWidget: Widget {
  let kind: String = "BattleMapWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: BattleMapTimelineProvider()) { entry in
      BattleMapEntryView(entry: entry)
    }
    .configurationDisplayName("對戰地圖")
    .description("顯示共編單字集對戰的攻佔領地地圖")
    .supportedFamilies([.systemLarge, .systemExtraLarge])
  }
}

// MARK: - Widget Configuration

@main
struct KnowledgeBitWidgetBundle: WidgetBundle {
  var body: some Widget {
    KnowledgeWidget()
    BattleMapWidget()
  }
}

struct KnowledgeWidget: Widget {
  let kind: String = "KnowledgeWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: ConfigurationAppIntent.self,
      provider: CardTimelineProvider()
    ) { entry in
      KnowledgeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("知識小工具")
    .description("在桌面或鎖定畫面複習知識")
    // ⚠️ 關鍵：加入 accessory 系列以支援鎖定畫面
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .accessoryCircular,     // 圓形 (鎖定畫面)
      .accessoryRectangular,  // 矩形 (鎖定畫面)
      .accessoryInline        // 文字列 (鎖定畫面/日期旁)
    ])
  }
}
