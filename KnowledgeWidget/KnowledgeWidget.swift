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

// MARK: - WordSet Forward Declaration
@Model
final class WordSet {
  @Attribute(.unique) var id: UUID
  var title: String
  var level: String?
  var createdAt: Date
  @Relationship(deleteRule: .cascade, inverse: \Card.wordSet) var cards: [Card] = []

  init() {
    self.id = UUID()
    self.title = ""
    self.level = nil
    self.createdAt = Date()
    self.cards = []
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
  
  // 從 App Group UserDefaults 讀取今日到期卡片數
  // 防呆邏輯：如果讀不到資料，返回預設值 0
  private func getTodayDueCount() -> Int {
    guard let defaults = AppGroup.sharedUserDefaults() else {
      // App Group 不可用，返回預設值
      return 0
    }
    let count = defaults.integer(forKey: AppGroup.Keys.todayDueCount)
    // 確保返回值為非負數
    return max(count, 0)
  }
  
  // 從 App Group UserDefaults 讀取用戶資料（供 Widget 顯示使用）
  // 確保處理所有 nil 情況並提供合理的預設值
  private func getUserProfile() -> (displayName: String, level: Int, exp: Int, expToNext: Int) {
    guard let defaults = AppGroup.sharedUserDefaults() else {
      // App Group 不可用，返回預設值
      return ("使用者", 1, 0, 100)
    }
    
    // 讀取 displayName，如果為 nil 則使用預設值
    let displayName = defaults.string(forKey: AppGroup.Keys.displayName) ?? "使用者"
    
    // 讀取 level，確保至少為 1
    let level = max(defaults.integer(forKey: AppGroup.Keys.level), 1)
    
    // 讀取 exp，確保至少為 0
    let exp = max(defaults.integer(forKey: AppGroup.Keys.exp), 0)
    
    // 讀取 expToNext，如果為 0 或未設定，根據 level 計算預設值
    let expToNext = defaults.integer(forKey: AppGroup.Keys.expToNext)
    let finalExpToNext: Int
    if expToNext > 0 {
      finalExpToNext = expToNext
    } else {
      // 如果未設定，根據 level 計算（基礎值 100，每級增加 20%）
      let baseExp = 100
      let multiplier = pow(1.2, Double(level - 1))
      finalExpToNext = max(Int(Double(baseExp) * multiplier), 100)
    }
    
    return (displayName, level, exp, finalExpToNext)
  }

  func placeholder(in context: Context) -> CardEntry {
    // Placeholder 使用預設值，確保 Widget 在第一次載入時不會顯示空白
    let placeholderCard = Card(title: "TCP Handshake", content: "建立連線的三向交握過程...", wordSet: nil)
    let cardIDs = [placeholderCard.id.uuidString]
    // 使用預設的到期卡片數（5），實際值會在 timeline 中從 AppGroup 讀取
    return CardEntry(cards: [placeholderCard], index: 0, cardIDs: cardIDs, todayDueCount: 5)
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> CardEntry {
    let allCards = await KnowledgeBitSharedContainer.fetchAllCards()
    
    // 讀取今日到期卡片數（帶防呆預設值）
    let todayDueCount = getTodayDueCount()

    // 如果沒有卡片，返回空的 Entry（Widget 會顯示預設狀態）
    if allCards.isEmpty {
      return CardEntry()
    }

    let storedCardIDs = CardIndexStore.getSelectedCardIDs()
    let cardsForWidget: [Card]
    let cardIDs: [String]

    if !storedCardIDs.isEmpty {
      let fetchedCards = await KnowledgeBitSharedContainer.fetchCardsByIDs(storedCardIDs)
      if !fetchedCards.isEmpty {
        cardsForWidget = fetchedCards
        cardIDs = storedCardIDs
      } else {
        cardsForWidget = await KnowledgeBitSharedContainer.selectCardsForWidget(from: allCards)
        cardIDs = cardsForWidget.map { $0.id.uuidString }
        CardIndexStore.setSelectedCardIDs(cardIDs)
      }
    } else {
      cardsForWidget = await KnowledgeBitSharedContainer.selectCardsForWidget(from: allCards)
      cardIDs = cardsForWidget.map { $0.id.uuidString }
      CardIndexStore.setSelectedCardIDs(cardIDs)
    }

    let currentIndex = CardIndexStore.getCurrentIndex()
    let validIndex = CardIndexStore.clampIndex(currentIndex, cardCount: cardsForWidget.count)

    if validIndex != currentIndex {
      CardIndexStore.setCurrentIndex(validIndex)
    }

    return CardEntry(cards: cardsForWidget, index: validIndex, cardIDs: cardIDs, todayDueCount: todayDueCount)
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<CardEntry> {
    let allCards = await KnowledgeBitSharedContainer.fetchAllCards()
    
    // 讀取今日到期卡片數（帶防呆預設值）
    let todayDueCount = getTodayDueCount()

    // 如果沒有卡片，返回空的 Entry 並設定下次更新時間
    if allCards.isEmpty {
      let entry = CardEntry() // 使用預設值：空卡片、Level 1、EXP 0
      let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    let storedCardIDs = CardIndexStore.getSelectedCardIDs()
    let cardsForWidget: [Card]
    let cardIDs: [String]

    if !storedCardIDs.isEmpty {
      let fetchedCards = await KnowledgeBitSharedContainer.fetchCardsByIDs(storedCardIDs)
      if !fetchedCards.isEmpty {
        cardsForWidget = fetchedCards
        cardIDs = storedCardIDs
      } else {
        cardsForWidget = await KnowledgeBitSharedContainer.selectCardsForWidget(from: allCards)
        cardIDs = cardsForWidget.map { $0.id.uuidString }
        CardIndexStore.setSelectedCardIDs(cardIDs)
      }
    } else {
      cardsForWidget = await KnowledgeBitSharedContainer.selectCardsForWidget(from: allCards)
      cardIDs = cardsForWidget.map { $0.id.uuidString }
      CardIndexStore.setSelectedCardIDs(cardIDs)
    }

    let currentIndex = CardIndexStore.getCurrentIndex()
    let validIndex = CardIndexStore.clampIndex(currentIndex, cardCount: cardsForWidget.count)

    if validIndex != currentIndex {
      CardIndexStore.setCurrentIndex(validIndex)
    }

    let now = Date()
    let intervalMinutes = 15
    var entries: [CardEntry] = []

    for i in 0..<cardsForWidget.count {
      let entryDate = Calendar.current.date(byAdding: .minute, value: intervalMinutes * i, to: now)!
      let entry = CardEntry(
        cards: cardsForWidget,
        index: (validIndex + i) % cardsForWidget.count,
        cardIDs: cardIDs,
        date: entryDate,
        todayDueCount: todayDueCount
      )
      entries.append(entry)
    }

    let nextRefresh = Calendar.current.date(
      byAdding: .minute,
      value: intervalMinutes * cardsForWidget.count,
      to: now
    )!

    return Timeline(entries: entries, policy: .after(nextRefresh))
  }
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
        VStack(alignment: .leading, spacing: 2) {
          Text(card.title)
            .font(.headline)
            .bold()
            .lineLimit(1)

          Text(card.content)
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
          
          // 今日到期數
          if entry.todayDueCount > 0 {
            HStack(spacing: 4) {
              Image(systemName: "clock.fill")
                .font(.caption2)
              Text("\(entry.todayDueCount)")
                .font(.caption2)
                .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.8))
            .cornerRadius(4)
          }
          
          Image(systemName: "lightbulb.fill")
            .font(.caption)
            .foregroundColor(.yellow)
        }
        .padding(.bottom, 8)

        // Main content
        if let card = entry.currentCard {
          Link(destination: URL(string: "knowledgebit://card?id=\(card.title)")!) {
            VStack(alignment: .leading) {
              Text(card.title)
                .font(.headline)
                .bold()
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

              Text(card.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
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

        Spacer()

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

// MARK: - Widget Configuration

@main
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
