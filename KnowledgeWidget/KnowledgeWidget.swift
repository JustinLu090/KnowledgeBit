import WidgetKit
import SwiftUI
import SwiftData
import AppIntents


struct RefreshCardIntent: AppIntent {
  static var title: LocalizedStringResource = "換一張卡片"

  init() {}

  func perform() async throws -> some IntentResult {
    return .result()
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let cardTitle: String
  let cardContent: String
  let deckName: String
}

struct Provider: TimelineProvider {
  let appGroupIdentifier = "group.com.lu.KnowledgeBit"

  @MainActor
  func fetchRandomCard() -> SimpleEntry {
    let schema = Schema([Card.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier(appGroupIdentifier))

    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
      let context = container.mainContext

      let descriptor = FetchDescriptor<Card>()
      let cards = try context.fetch(descriptor)

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
      // 每次 Timeline 被觸發（包含按鈕點擊），就會跑這行
      let entry = await fetchRandomCard()

      let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!

      let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
      completion(timeline)
    }
  }
}

struct KnowledgeWidgetEntryView : View {
  var entry: Provider.Entry

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(entry.deckName)
          .font(.caption2)
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
      .padding(.bottom, 8)


      Link(destination: URL(string: "knowledgebit://card?id=\(entry.cardTitle)")!) {
        VStack(alignment: .leading) {
          Text(entry.cardTitle)
            .font(.headline)
            .bold()
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading) // 靠左對齊

          Text(entry.cardContent)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading) // 靠左對齊
        }
      }

      Spacer()


      HStack {
        Button(intent: RefreshCardIntent()) {
          Image(systemName: "arrow.left.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.gray.opacity(0.3))
        }
        .buttonStyle(.plain) // 重要：讓按鈕不要有背景色塊

        Spacer()

        // 指示點 (裝飾用，讓它看起來像可以滑動)
        HStack(spacing: 4) {
          Circle().fill(Color.gray).frame(width: 4, height: 4)
          Circle().fill(Color.gray.opacity(0.3)).frame(width: 4, height: 4)
          Circle().fill(Color.gray.opacity(0.3)).frame(width: 4, height: 4)
        }

        Spacer()

        // 下一張按鈕
        Button(intent: RefreshCardIntent()) {
          Image(systemName: "arrow.right.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.blue)
        }
        .buttonStyle(.plain)
      }
      .padding(.top, 8)
    }
    .padding()
    .containerBackground(for: .widget) {
      Color(UIColor.systemBackground)
    }
  }
}

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
