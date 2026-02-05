// KnowledgeBitApp.swift
import SwiftUI
import SwiftData

@main
struct KnowledgeBitApp: App {
  // 輔助函數：創建 ModelContainer，處理錯誤和遷移
  private static func createModelContainer() -> ModelContainer {
    let schema = Schema([
      Card.self,
      StudyLog.self,
      WordSet.self
    ])
    
    // 嘗試使用 App Group container，如果失敗則回退到默認容器
    let modelConfiguration: ModelConfiguration
    
    // 檢查 App Group 是否可用
    if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil {
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
      // 如果是資料庫遷移問題，嘗試刪除舊資料庫並重新創建
      print("⚠️ [Migration] 資料庫遷移失敗，嘗試重新創建資料庫...")
      print("錯誤詳情: \(error.localizedDescription)")
      
      // 嘗試刪除舊資料庫檔案（SwiftData 可能使用不同的檔案名稱）
      if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
        let fileManager = FileManager.default
        let possibleDBFiles = [
          "default.store",
          "default.sqlite",
          "default.sqlite-wal",
          "default.sqlite-shm"
        ]
        
        var deletedAny = false
        for fileName in possibleDBFiles {
          let dbURL = groupURL.appendingPathComponent(fileName)
          if fileManager.fileExists(atPath: dbURL.path) {
            do {
              try fileManager.removeItem(at: dbURL)
              print("✅ [Migration] 已刪除: \(fileName)")
              deletedAny = true
            } catch {
              print("⚠️ [Migration] 無法刪除 \(fileName): \(error.localizedDescription)")
            }
          }
        }
        
        if deletedAny {
          print("✅ [Migration] 已清理舊資料庫，將重新創建")
          // 重新嘗試創建
          do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
          } catch {
            // 如果還是失敗，繼續到下面的錯誤處理
            print("❌ [Migration] 重新創建仍然失敗: \(error.localizedDescription)")
          }
        }
      }
      
      // 如果還是失敗，提供詳細錯誤信息
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
      - Try deleting the app and reinstalling to reset the database
      """
      print(errorMessage)
      fatalError(errorMessage)
    }
  }
  
  var sharedModelContainer: ModelContainer = {
    createModelContainer()
  }()

  // 建立 ExperienceStore singleton，供整個 App 使用
  @StateObject private var experienceStore = ExperienceStore()
  @StateObject private var taskService = TaskService()
  
  var body: some Scene {
    WindowGroup {
      MainTabView()
        .environmentObject(experienceStore)
        .environmentObject(taskService)
    }
    .modelContainer(sharedModelContainer)
  }
}
