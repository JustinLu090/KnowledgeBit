import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - WordSet Forward Declaration
// Note: Widget Extension needs access to WordSet for schema, but can't import from main app
// This is a minimal declaration for schema purposes only
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

/// Shared App Group identifier for data synchronization between main app and widget extension
private let sharedAppGroupIdentifier = "group.com.timmychen.KnowledgeBit"

// MARK: - Shared SwiftData Container

/// Shared ModelContainer using App Group - provides access to the same SwiftData store as the main app
enum KnowledgeBitSharedContainer {
  static let appGroupIdentifier = sharedAppGroupIdentifier
  
  static var container: ModelContainer? = {
    let schema = Schema([
      Card.self,
      StudyLog.self,
      WordSet.self
    ])
    
    // Check if App Group is available
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
      print("✅ Widget: Shared ModelContainer created successfully")
      return container
    } catch {
      print("❌ Widget: Failed to create ModelContainer: \(error.localizedDescription)")
      return nil
    }
  }()
  
  /// Fetch all cards from the shared SwiftData container
  @MainActor
  static func fetchAllCards() -> [Card] {
    guard let container = container else {
      print("⚠️ Widget: Shared container not available")
      return []
    }
    
      let context = container.mainContext
    let descriptor = FetchDescriptor<Card>(
      sortBy: [SortDescriptor(\.createdAt, order: .forward)]
    )

    do {
      let cards = try context.fetch(descriptor)
      return cards
    } catch {
      print("❌ Widget: Failed to fetch cards: \(error.localizedDescription)")
      return []
    }
  }
  
  /// Select up to 5 cards for the widget (randomly if more than 5 available)
  @MainActor
  static func selectCardsForWidget(from allCards: [Card]) -> [Card] {
    if allCards.count <= 5 {
      return allCards
      } else {
      // Randomly select 5 distinct cards
      return Array(allCards.shuffled().prefix(5))
    }
  }
  
  /// Fetch cards by their UUID strings
  @MainActor
  static func fetchCardsByIDs(_ cardIDs: [String]) -> [Card] {
    guard let container = container else {
      return []
    }
    
    let context = container.mainContext
    let descriptor = FetchDescriptor<Card>()
    
    do {
      let allCards = try context.fetch(descriptor)
      // Filter cards by matching UUID strings
      return allCards.filter { card in
        cardIDs.contains(card.id.uuidString)
      }
    } catch {
      print("❌ Widget: Failed to fetch cards by IDs: \(error.localizedDescription)")
      return []
    }
  }
}

// MARK: - Card Index Storage

/// Manages the current card index and selected card subset in App Group UserDefaults
struct CardIndexStore {
  private static let defaults = UserDefaults(suiteName: sharedAppGroupIdentifier)
  private static let currentIndexKey = "widget.currentCardIndex"
  private static let selectedCardIDsKey = "widget.selectedCardIDs"
  
  /// Get the current card index (defaults to 0)
  static func getCurrentIndex() -> Int {
    return defaults?.integer(forKey: currentIndexKey) ?? 0
  }
  
  /// Set the current card index
  static func setCurrentIndex(_ index: Int) {
    defaults?.set(index, forKey: currentIndexKey)
    defaults?.synchronize()
  }
  
  /// Get the stored selected card IDs (UUID strings)
  static func getSelectedCardIDs() -> [String] {
    return defaults?.stringArray(forKey: selectedCardIDsKey) ?? []
  }
  
  /// Store the selected card IDs
  static func setSelectedCardIDs(_ ids: [String]) {
    defaults?.set(ids, forKey: selectedCardIDsKey)
    defaults?.synchronize()
  }
  
  /// Adjust index to be valid for the given card count (handles deletions/additions)
  static func clampIndex(_ index: Int, cardCount: Int) -> Int {
    guard cardCount > 0 else { return 0 }
    // Wrap around if index is out of bounds
    if index < 0 {
      return cardCount - 1
    } else if index >= cardCount {
      return 0
    }
    return index
  }
  
  /// Update index to next card (with wrapping) within the subset
  static func nextIndex(cardCount: Int) -> Int {
    guard cardCount > 0 else { return 0 }
    let current = getCurrentIndex()
    let next = (current + 1) % cardCount
    setCurrentIndex(next)
    return next
  }
  
  /// Update index to previous card (with wrapping) within the subset
  static func previousIndex(cardCount: Int) -> Int {
    guard cardCount > 0 else { return 0 }
    let current = getCurrentIndex()
    let previous = current - 1 < 0 ? cardCount - 1 : current - 1
    setCurrentIndex(previous)
    return previous
  }
}

// MARK: - App Intents

/// AppIntent to navigate to the next card
struct NextCardIntent: AppIntent {
  static var title: LocalizedStringResource = "下一張卡片"
  static var description = IntentDescription("切換到下一張知識卡片")
  
  func perform() async throws -> some IntentResult {
    // Get the stored card IDs for the widget subset
    let storedCardIDs = CardIndexStore.getSelectedCardIDs()
    
    guard !storedCardIDs.isEmpty else {
      print("⚠️ NextCardIntent: No stored card subset")
      WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      return .result()
    }
    
    // Fetch the cards from the stored subset
    let cards = await KnowledgeBitSharedContainer.fetchCardsByIDs(storedCardIDs)
    
    guard !cards.isEmpty else {
      print("⚠️ NextCardIntent: Stored cards no longer available, regenerating subset")
      WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      return .result()
    }
    
    // Update to next index within the subset (with wrapping)
    let newIndex = CardIndexStore.nextIndex(cardCount: cards.count)
    print("✅ NextCardIntent: Moved to card index \(newIndex) of \(cards.count) in subset")
    
    // Reload widget to show the new card
    WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
    
    return .result()
  }
}

/// AppIntent to navigate to the previous card
struct PreviousCardIntent: AppIntent {
  static var title: LocalizedStringResource = "上一張卡片"
  static var description = IntentDescription("切換到上一張知識卡片")
  
  func perform() async throws -> some IntentResult {
    // Get the stored card IDs for the widget subset
    let storedCardIDs = CardIndexStore.getSelectedCardIDs()
    
    guard !storedCardIDs.isEmpty else {
      print("⚠️ PreviousCardIntent: No stored card subset")
      WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      return .result()
    }
    
    // Fetch the cards from the stored subset
    let cards = await KnowledgeBitSharedContainer.fetchCardsByIDs(storedCardIDs)
    
    guard !cards.isEmpty else {
      print("⚠️ PreviousCardIntent: Stored cards no longer available, regenerating subset")
      WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      return .result()
    }
    
    // Update to previous index within the subset (with wrapping)
    let newIndex = CardIndexStore.previousIndex(cardCount: cards.count)
    print("✅ PreviousCardIntent: Moved to card index \(newIndex) of \(cards.count) in subset")
    
    // Reload widget to show the new card
    WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
    
    return .result()
  }
}

// MARK: - Configuration Intent (Dummy - not used for configuration, but required for AppIntentConfiguration)

struct ConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "知識小工具"
  static var description = IntentDescription("顯示知識卡片")
}

// MARK: - Timeline Entry

struct CardEntry: TimelineEntry {
  let date: Date
  let cards: [Card]  // Subset of up to 5 cards for this widget session
  let cardIndex: Int  // Current index within the subset
  let cardIDs: [String]  // UUID strings of selected cards for persistence
  
  /// Current card from the subset
  var currentCard: Card? {
    guard cardIndex >= 0 && cardIndex < cards.count else { return nil }
    return cards[cardIndex]
  }
  
  /// Total number of cards in the subset
  var totalCards: Int {
    cards.count
  }
  
  /// Create entry with a subset of cards
  init(cards: [Card], index: Int, cardIDs: [String], date: Date = Date()) {
    self.date = date
    self.cards = cards
    self.cardIndex = index
    self.cardIDs = cardIDs
  }
  
  /// Create placeholder entry when no cards are available
  init() {
    self.date = Date()
    self.cards = []
    self.cardIndex = 0
    self.cardIDs = []
  }
}

// MARK: - Timeline Provider

/// AppIntentTimelineProvider that reads the current card index and displays the corresponding card
struct CardTimelineProvider: AppIntentTimelineProvider {
  typealias Intent = ConfigurationAppIntent
  typealias Entry = CardEntry
  
  func placeholder(in context: Context) -> CardEntry {
    // Return a placeholder card for preview
    let placeholderCard = Card(title: "TCP Handshake", content: "建立連線的三向交握過程...", wordSet: nil)
    let cardIDs = [placeholderCard.id.uuidString]
    return CardEntry(cards: [placeholderCard], index: 0, cardIDs: cardIDs)
  }
  
  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> CardEntry {
    // Fetch all cards
    let allCards = await KnowledgeBitSharedContainer.fetchAllCards()
    
    if allCards.isEmpty {
      return CardEntry()
    }
    
    // Get or create the widget subset (up to 5 cards)
    let storedCardIDs = CardIndexStore.getSelectedCardIDs()
    let cardsForWidget: [Card]
    let cardIDs: [String]
    
    if !storedCardIDs.isEmpty {
      // Try to use stored subset
      let fetchedCards = await KnowledgeBitSharedContainer.fetchCardsByIDs(storedCardIDs)
      if !fetchedCards.isEmpty {
        cardsForWidget = fetchedCards
        cardIDs = storedCardIDs
      } else {
        // Stored cards no longer exist, create new subset
        cardsForWidget = await KnowledgeBitSharedContainer.selectCardsForWidget(from: allCards)
        cardIDs = cardsForWidget.map { $0.id.uuidString }
        CardIndexStore.setSelectedCardIDs(cardIDs)
      }
    } else {
      // No stored subset, create new one
      cardsForWidget = await KnowledgeBitSharedContainer.selectCardsForWidget(from: allCards)
      cardIDs = cardsForWidget.map { $0.id.uuidString }
      CardIndexStore.setSelectedCardIDs(cardIDs)
    }
    
    // Get current index from storage (updated by AppIntents)
    let currentIndex = CardIndexStore.getCurrentIndex()
    let validIndex = CardIndexStore.clampIndex(currentIndex, cardCount: cardsForWidget.count)
    
    // Update stored index if it was out of bounds
    if validIndex != currentIndex {
      CardIndexStore.setCurrentIndex(validIndex)
    }
    
    print("📸 Widget snapshot: Using index \(validIndex) of \(cardsForWidget.count) cards")
    return CardEntry(cards: cardsForWidget, index: validIndex, cardIDs: cardIDs)
  }
  
  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<CardEntry> {
    // Fetch all cards from shared SwiftData container
    let allCards = await KnowledgeBitSharedContainer.fetchAllCards()
    print("🔍 Widget sees \(allCards.count) total cards")
    
    if allCards.isEmpty {
      // No cards available - show placeholder entry
      let entry = CardEntry()
      // Refresh in 15 minutes in case cards are added
      let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    // Get or create the widget subset (up to 5 cards)
    let storedCardIDs = CardIndexStore.getSelectedCardIDs()
    let cardsForWidget: [Card]
    let cardIDs: [String]
    
    if !storedCardIDs.isEmpty {
      // Try to use stored subset
      let fetchedCards = await KnowledgeBitSharedContainer.fetchCardsByIDs(storedCardIDs)
      if !fetchedCards.isEmpty {
        cardsForWidget = fetchedCards
        cardIDs = storedCardIDs
        print("✅ Widget: Using stored subset of \(cardsForWidget.count) cards")
      } else {
        // Stored cards no longer exist, create new subset
        cardsForWidget = await KnowledgeBitSharedContainer.selectCardsForWidget(from: allCards)
        cardIDs = cardsForWidget.map { $0.id.uuidString }
        CardIndexStore.setSelectedCardIDs(cardIDs)
        print("🔄 Widget: Regenerated subset of \(cardsForWidget.count) cards")
      }
    } else {
      // No stored subset, create new one
      cardsForWidget = await KnowledgeBitSharedContainer.selectCardsForWidget(from: allCards)
      cardIDs = cardsForWidget.map { $0.id.uuidString }
      CardIndexStore.setSelectedCardIDs(cardIDs)
      print("🆕 Widget: Created new subset of \(cardsForWidget.count) cards")
    }
    
    // Get current index and ensure it's valid
    let currentIndex = CardIndexStore.getCurrentIndex()
    let validIndex = CardIndexStore.clampIndex(currentIndex, cardCount: cardsForWidget.count)
    
    // Update stored index if it was out of bounds
    if validIndex != currentIndex {
      CardIndexStore.setCurrentIndex(validIndex)
      print("⚠️ Widget: Adjusted index from \(currentIndex) to \(validIndex)")
    }
    
    // Create timeline entries that rotate through the subset
    // Each entry is 15 minutes apart, cycling through all cards in the subset
    let now = Date()
    let intervalMinutes = 15
    var entries: [CardEntry] = []
    
    // Create entries for one full cycle through the subset
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
    
    // Calculate next refresh (after one full cycle)
    let nextRefresh = Calendar.current.date(
      byAdding: .minute,
      value: intervalMinutes * cardsForWidget.count,
      to: now
    )!
    
    print("📅 Widget timeline: \(entries.count) entries, next refresh at \(nextRefresh)")
    return Timeline(entries: entries, policy: .after(nextRefresh))
  }
}

// MARK: - Widget View

struct KnowledgeWidgetEntryView: View {
  var entry: CardEntry

  var body: some View {
    VStack(spacing: 0) {
      // Top row: WordSet tag and icon
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

      // Main content area - tappable to open app
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
        // No cards available message
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

      // Bottom row: Navigation arrows and page indicator
      HStack {
        // Previous card button (interactive)
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

        // Page indicator dots (shows current position)
        if entry.totalCards > 0 {
          let currentIndex = entry.cardIndex
          HStack(spacing: 4) {
            ForEach(0..<entry.totalCards, id: \.self) { index in
              Circle()
                .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 4, height: 4)
            }
          }
        } else {
          HStack(spacing: 4) {
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 4, height: 4)
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 4, height: 4)
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 4, height: 4)
          }
        }

        Spacer()

        // Next card button (interactive)
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
    .description("點擊箭頭切換知識卡片")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
