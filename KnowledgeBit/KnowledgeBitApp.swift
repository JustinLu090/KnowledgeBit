// KnowledgeBitApp.swift
import SwiftUI
import SwiftData

@main
struct KnowledgeBitApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Card.self,
      StudyLog.self
    ])
    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      // ⚠️ 關鍵修改：指定 App Group ID
      groupContainer: .identifier("group.com.lu.KnowledgeBit")
    )

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}
