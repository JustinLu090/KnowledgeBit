import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

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

// MARK: - App Group Configuration
private let sharedAppGroupIdentifier = "group.com.timmychen.KnowledgeBit"

// MARK: - Shared SwiftData Container
enum KnowledgeBitSharedContainer {
  static let appGroupIdentifier = sharedAppGroupIdentifier

  static var container: ModelContainer? = {
    let schema = Schema([
      Card.self,
      StudyLog.self,
      WordSet.self
    ])

    guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil else {
      print("⚠️ Widget: App Group not available")
      return nil
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
    // 先嘗試從 shared ModelContainer 讀取
    if let container = container {
      let context = container.mainContext
      let descriptor = FetchDescriptor<Card>(sortBy: [SortDescriptor(\Card.createdAt, order: .forward)])
      do {
        let cards = try context.fetch(descriptor)
        if !cards.isEmpty {
          return cards
        }
        // 若 fetch 出來是空的，再嘗試 fallback 到 cachedCards
      } catch {
        // 如有錯誤，繼續走 fallback
      }
    }

    // fallback: 從 App Group 的 UserDefaults 讀取快取卡片資料
    if let defaults = UserDefaults(suiteName: appGroupIdentifier),
       let cached = defaults.array(forKey: "widget.cachedCards") as? [[String: String]],
       !cached.isEmpty {
      return cached.compactMap { dict in
        let title = dict["title"] ?? ""
        let content = dict["content"] ?? ""
        let idStr = dict["id"] ?? UUID().uuidString
        let wordSetTitle = dict["wordSetTitle"] ?? ""
        let card = Card(title: title, content: content, wordSet: nil)
        if let uuid = UUID(uuidString: idStr) {
          card.id = uuid
        }
        if !wordSetTitle.isEmpty {
          let ws = WordSet()
          ws.title = wordSetTitle
          card.wordSet = ws
        }
        return card
      }
    }

    return []
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
    // 先試圖從 shared ModelContainer 讀取所有卡片，然後依照 cardIDs 順序回傳
    if let container = container {
      let context = container.mainContext
      let descriptor = FetchDescriptor<Card>()
      do {
        let allCards = try context.fetch(descriptor)
        // Preserve the order defined by cardIDs: build a map and then return cards in that order
        let cardMap = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id.uuidString, $0) })
        let mapped = cardIDs.compactMap { cardMap[$0] }
        if !mapped.isEmpty {
          return mapped
        }
        // 若 mapped 為空，繼續走 fallback
      } catch {
        // 讀取錯誤，走 fallback
      }
    }

    // fallback: 從 App Group 的 cachedCards 找尋對應 id，並保留 cardIDs 的順序
    if let defaults = UserDefaults(suiteName: appGroupIdentifier),
       let cached = defaults.array(forKey: "widget.cachedCards") as? [[String: String]],
       !cached.isEmpty {
      let cardMap = Dictionary(uniqueKeysWithValues: cached.compactMap { dict -> (String, Card)? in
        guard let id = dict["id"] else { return nil }
        let title = dict["title"] ?? ""
        let content = dict["content"] ?? ""
        let wordSetTitle = dict["wordSetTitle"] ?? ""
        let card = Card(title: title, content: content, wordSet: nil)
        if let uuid = UUID(uuidString: id) { card.id = uuid }
        if !wordSetTitle.isEmpty {
          let ws = WordSet()
          ws.title = wordSetTitle
          card.wordSet = ws
        }
        return (id, card)
      })
      return cardIDs.compactMap { cardMap[$0] }
    }

    return []
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

  var currentCard: Card? {
    guard cardIndex >= 0 && cardIndex < cards.count else { return nil }
    return cards[cardIndex]
  }

  var totalCards: Int {
    cards.count
  }

  // 初始化：一般情況
  init(cards: [Card], index: Int, cardIDs: [String], date: Date = Date()) {
    self.date = date
    self.cards = cards
    self.cardIndex = index
    self.cardIDs = cardIDs
    self.todoCount = cards.count // 簡單起見，這裡用本次輪播的總張數當作待辦數
  }

  // 初始化：Placeholder
  init() {
    self.date = Date()
    self.cards = []
    self.cardIndex = 0
    self.cardIDs = []
    self.todoCount = 0
  }
}

// MARK: - Timeline Provider
struct CardTimelineProvider: AppIntentTimelineProvider {
  typealias Intent = ConfigurationAppIntent
  typealias Entry = CardEntry

  func placeholder(in context: Context) -> CardEntry {
    let placeholderCard = Card(title: "TCP Handshake", content: "建立連線的三向交握過程...", wordSet: nil)
    let cardIDs = [placeholderCard.id.uuidString]
    return CardEntry(cards: [placeholderCard], index: 0, cardIDs: cardIDs)
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> CardEntry {
    let allCards = await KnowledgeBitSharedContainer.fetchAllCards()

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

    return CardEntry(cards: cardsForWidget, index: validIndex, cardIDs: cardIDs)
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<CardEntry> {
    let allCards = await KnowledgeBitSharedContainer.fetchAllCards()

    if allCards.isEmpty {
      let entry = CardEntry()
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
        date: entryDate
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
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .systemLarge,
      .systemExtraLarge,
      .accessoryCircular,
      .accessoryRectangular,
      .accessoryInline
    ])
  }
}
