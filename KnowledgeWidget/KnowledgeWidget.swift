import WidgetKit
import SwiftUI
import SwiftData

// 1. 定義 Widget 要顯示的資料結構
struct SimpleEntry: TimelineEntry {
  let date: Date
  let cardTitle: String
  let cardContent: String
  let deckName: String
}

struct Provider: TimelineProvider {
  // ⚠️ 請務必將此處換成您剛剛設定的 App Group ID
  let appGroupIdentifier = "group.com.lu.KnowledgeBit"

  // 負責從資料庫抓取一張卡片
  @MainActor
  func fetchRandomCard() -> SimpleEntry {
    // 1. 設定資料庫路徑 (指向共用區)
    let schema = Schema([Card.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier(appGroupIdentifier))

    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
      let context = container.mainContext

      // 2. 抓取所有卡片
      let descriptor = FetchDescriptor<Card>()
      let cards = try context.fetch(descriptor)

      // 3. 隨機挑一張，如果沒卡片就顯示預設文字
      if let randomCard = cards.randomElement() {
        return SimpleEntry(date: Date(), cardTitle: randomCard.title, cardContent: randomCard.content, deckName: randomCard.deck)
      } else {
        return SimpleEntry(date: Date(), cardTitle: "尚無卡片", cardContent: "請先進入 App 新增知識卡片", deckName: "系統")
      }
    } catch {
      return SimpleEntry(date: Date(), cardTitle: "讀取錯誤", cardContent: error.localizedDescription, deckName: "Error")
    }
  }

  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), cardTitle: "TCP Handshake", cardContent: "建立連線的三向交握過程...", deckName: "CS")
  }

  func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
    Task {
      let entry = await fetchRandomCard()
      completion(entry)
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
    Task {
      // 1. 抓取資料
      let entry = await fetchRandomCard()

      // 2. 設定下次更新時間 (例如 15 分鐘後換一張)
      let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!

      // 3. 建立時間軸
      let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
      completion(timeline)
    }
  }
}

// 2. 設計 Widget 的外觀 (UI)
struct KnowledgeWidgetEntryView : View {
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(entry.deckName)
          .font(.caption)
          .fontWeight(.bold)
          .foregroundStyle(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.blue.opacity(0.8))
          .cornerRadius(4)
        Spacer()
        Image(systemName: "lightbulb.fill")
          .font(.caption)
          .foregroundColor(.yellow)
      }

      Text(entry.cardTitle)
        .font(.headline)
        .bold()
        .lineLimit(2)
        .minimumScaleFactor(0.8)

      Text(entry.cardContent)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(3) // 限制顯示行數，避免爆版

      Spacer()
    }
    .padding()
    // 為了支援 iOS 17 的 Widget 背景容器
    .containerBackground(for: .widget) {
      Color(UIColor.systemBackground)
    }
  }
}

// 3. Widget 設定入口
@main
struct KnowledgeWidget: Widget {
  let kind: String = "KnowledgeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      KnowledgeWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("知識小工具")
    .description("每天隨機複習一張卡片。")
    .supportedFamilies([.systemSmall, .systemMedium]) // 支援小和大尺寸
  }
}
