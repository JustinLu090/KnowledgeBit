// KnowledgeBitApp.swift
import SwiftUI
import SwiftData

@main
struct KnowledgeBitApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Card.self,
      StudyLog.self,
      WordSet.self
    ])
    
    // 嘗試使用 App Group container，如果失敗則回退到默認容器
    let modelConfiguration: ModelConfiguration
    
    // 檢查 App Group 是否可用
    if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
      // App Group 可用，使用共享容器
      modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        groupContainer: .identifier(AppGroup.identifier)
      )
      print("✅ Using App Group container: \(AppGroup.identifier)")
    } else {
      // App Group 不可用，使用默認容器（fallback）
      // ⚠️ 注意：這意味著 Widget 將無法訪問數據，請在 Xcode 中配置 App Groups capability
      print("⚠️ App Group not available, using default container. Widget will not work until App Groups is configured in Xcode.")
      modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
      )
    }

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      // 提供更詳細的錯誤信息
      let errorMessage = """
      ❌ Failed to create ModelContainer:
      Error: \(error.localizedDescription)
      
      Possible causes:
      1. App Groups capability not enabled in Xcode
      2. App Group ID mismatch between code and Xcode settings
      3. Database migration issue
      
      Please check:
      - Xcode > Signing & Capabilities > App Groups
      - Ensure both main app and widget extension have the same App Group ID
      """
      print(errorMessage)
      fatalError(errorMessage)
    }
  }()

  // 建立 ExperienceStore singleton，供整個 App 使用
  @StateObject private var experienceStore = ExperienceStore()
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(experienceStore)
    }
    .modelContainer(sharedModelContainer)
  }
}
