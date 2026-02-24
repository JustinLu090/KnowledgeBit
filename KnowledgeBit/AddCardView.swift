import SwiftUI
import SwiftData
#if canImport(GoogleGenerativeAI)
import GoogleGenerativeAI
#endif
import PhotosUI // 引入 PhotosUI
import UIKit    // 引入 UIKit 以支援 UIImage 處理
#if os(iOS)
import WidgetKit
#endif

struct AddCardView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss
  
  var cardToEdit: Card?
  var wordSet: WordSet?
  
  @Query(sort: \WordSet.title) private var allWordSets: [WordSet]
  
  @State private var title = ""
  @State private var content = ""
  @State private var selectedWordSet: WordSet?
  
  // --- A卡片種類
  @State private var cardKind: CardKind = .qa
  
  // --- AI 文字生成狀態 ---
  @State private var isGenerating = false
  @State private var showAIPrompt = false
  @State private var aiTopic = ""
  
  // --- AI 圖片生成狀態 ---
  @State private var selectedPhotoItem: PhotosPickerItem? = nil
  @State private var isProcessingImage = false
  
  // --- 錯誤處理 ---
  @State private var aiErrorMessage = ""
  @State private var showAIError = false
  
  private var isEditMode: Bool {
    cardToEdit != nil
  }
  
  private var canSave: Bool {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if cardKind == .quote {
      return !trimmedTitle.isEmpty
    } else {
      return !trimmedTitle.isEmpty || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
  
  var body: some View {
    NavigationStack {
      Form {
        
        // --- 1. AI 智慧製卡區塊 ---
        if !isEditMode {
          Section {
            Button {
              showAIPrompt = true
            } label: {
              HStack {
                Image(systemName: "sparkles")
                  .foregroundStyle(.purple)
                Text("AI 文字自動生成")
                  .foregroundStyle(.primary)
              }
            }
            .disabled(isGenerating || isProcessingImage)
            
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
              HStack {
                Image(systemName: "camera.viewfinder")
                  .foregroundStyle(.blue)
                Text("拍照/選圖製卡")
                  .foregroundStyle(.primary)
              }
            }
            .disabled(isGenerating || isProcessingImage)
            .onChange(of: selectedPhotoItem) {
              Task { await processSelectedImage() }
            }
            
            if isGenerating {
              HStack {
                ProgressView()
                Text("AI 正在撰寫卡片中...")
                  .font(.caption).foregroundStyle(.secondary)
              }
            } else if isProcessingImage {
              HStack {
                ProgressView()
                Text("AI 正在分析圖片內容...")
                  .font(.caption).foregroundStyle(.secondary)
              }
            }
          } header: {
            Text("AI 快速建立")
          }
        }
        
        // ✅ 2. 卡片種類
        Section(header: Text("卡片種類")) {
          Picker("種類", selection: $cardKind) {
            ForEach(CardKind.allCases) { kind in
              Text(kind.displayName).tag(kind)
            }
          }
          .pickerStyle(.segmented)
          
          if cardKind == .quote {
            Text("語錄卡片只顯示一句話，不會出現在複習/測驗中。")
              .font(.footnote)
              .foregroundStyle(.secondary)
          } else {
            Text("問題/答案卡片會進入複習與測驗。")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        
        // --- 3. 基本資訊 ---
        Section(header: Text(cardKind == .quote ? "語錄" : "標題 / 問題")) {
          if cardKind == .quote {
            // 語錄可能比一行長，用 TextEditor 更舒服
            TextEditor(text: $title)
              .frame(height: 90)
          } else {
            TextField("標題 (例如: TCP)", text: $title)
          }
        }
        
        // --- 4. 單字集選擇 ---
        Section(header: Text("單字集")) {
          Picker("選擇單字集", selection: $selectedWordSet) {
            Text("無 (或由 AI 自動分類)").tag(nil as WordSet?)
            ForEach(allWordSets, id: \.id) { wordSet in
              Text(wordSet.title).tag(wordSet as WordSet?)
            }
          }
        }
        
        // --- 5. 詳細內容（只有 QA 才顯示） ---
        if cardKind == .qa {
          Section(header: Text("詳細筆記 (Markdown)")) {
            TextEditor(text: $content)
              .frame(height: 200)
            
            Text("支援 Markdown：**粗體**、- 清單、# 標題、> 引用、`code`")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle(isEditMode ? "編輯卡片" : "新增卡片")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("儲存") { saveCard() }
            .disabled(!canSave && !isGenerating && !isProcessingImage)
        }
      }
      .onAppear { setupInitialState() }
      .alert("AI 文字製卡", isPresented: $showAIPrompt) {
        TextField("輸入主題 (例如: 多益單字)", text: $aiTopic)
        Button("生成", action: startTextAIGeneration)
        Button("取消", role: .cancel) {}
      }
      .alert("生成失敗", isPresented: $showAIError) {
        Button("好", role: .cancel) {}
      } message: {
        Text(aiErrorMessage)
      }
    }
  }
  
  // MARK: - Helper Functions
  
  private func setupInitialState() {
    if let card = cardToEdit {
      title = card.title
      content = card.content
      selectedWordSet = card.wordSet
      cardKind = card.kind
    } else {
      selectedWordSet = wordSet
      cardKind = .qa
    }
  }
  
  private func saveCard() {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Quote 卡片：只保留一句話，content 一律存空字串
    let finalTitle = trimmedTitle
    let finalContent = (cardKind == .quote) ? "" : content
    
    if let card = cardToEdit {
      card.kind = cardKind
      card.title = finalTitle
      card.content = finalContent
      card.wordSet = selectedWordSet ?? wordSet
    } else {
      let newCard = Card(
        title: finalTitle,
        content: finalContent,
        wordSet: selectedWordSet ?? wordSet,
        kind: cardKind
      )
      modelContext.insert(newCard)
    }
    
    try? modelContext.save()
    
#if os(iOS)
    // widget 同步（維持你原本邏輯：title/content/wordSetTitle）
    if let defaults = UserDefaults(suiteName: AppGroup.identifier) {
      print("🟢 App writing to shared UserDefaults (AppGroup): \(AppGroup.identifier)")
      do {
        let descriptor = FetchDescriptor<Card>(sortBy: [SortDescriptor(\Card.createdAt, order: .forward)])
        let allCards = try modelContext.fetch(descriptor)
        let selected: [Card] = allCards.count <= 5 ? allCards : Array(allCards.shuffled().prefix(5))
        let ids = selected.map { $0.id.uuidString }
        defaults.set(ids, forKey: "widget.selectedCardIDs")
        defaults.set(0, forKey: "widget.currentCardIndex")
        
        var cachedArray: [[String: String]] = []
        for c in selected {
          cachedArray.append([
            "id": c.id.uuidString,
            "title": c.title,
            "content": c.content,
            "wordSetTitle": c.wordSet?.title ?? ""
          ])
        }
        defaults.set(cachedArray, forKey: "widget.cachedCards")
        defaults.synchronize()
        
        // read-back verification
        if let cached = defaults.array(forKey: "widget.cachedCards") as? [[String: String]] {
          print("✅ widget.cachedCards written successfully, count: \(cached.count)")
        } else {
          print("⚠️ widget.cachedCards read-back is nil after write")
        }
        
        if let idsRead = defaults.array(forKey: "widget.selectedCardIDs") as? [String] {
          print("✅ widget.selectedCardIDs written successfully, count: \(idsRead.count)")
        } else {
          print("⚠️ widget.selectedCardIDs read-back is nil after write")
        }
        
      } catch {
        print("🔴 Failed to prepare widget cached cards: \(error)")
        defaults.removeObject(forKey: "widget.selectedCardIDs")
        defaults.set(0, forKey: "widget.currentCardIndex")
        defaults.removeObject(forKey: "widget.cachedCards")
        defaults.synchronize()
      }
    } else {
      print("❌ UserDefaults(suiteName:) returned nil — App Group not available: \(AppGroup.identifier)")
    }
    
    if #available(iOS 16.0, *) {
      Task {
        try? await Task.sleep(nanoseconds: 500_000_000)
        WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      }
    }
#endif
    
    dismiss()
  }
  
  // MARK: - AI Logic: 文字生成
  
  private func startTextAIGeneration() {
    guard !aiTopic.isEmpty else { return }
    isGenerating = true
    
    Task {
      do {
        let generator = AIGenerator()
        let generatedCards = try await generator.generateCards(topic: aiTopic)
        saveGeneratedCards(generatedCards)
      } catch {
        handleAIError(error)
      }
      isGenerating = false
    }
  }
  
  // MARK: - AI Logic: 圖片生成 (修正版)
  
  // ⚠️ 修正重點：加上 @MainActor 確保 UI 執行緒安全
  @MainActor
  private func processSelectedImage() async {
    guard let item = selectedPhotoItem else { return }
    isProcessingImage = true
    
    do {
      print("📸 開始讀取照片...")
      
      // ⚠️ 修正重點：更穩健的資料讀取
      guard let data = try await item.loadTransferable(type: Data.self) else {
        throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法讀取圖片資料"])
      }
      
      guard let uiImage = UIImage(data: data) else {
        throw NSError(domain: "ImageError", code: -2, userInfo: [NSLocalizedDescriptionKey: "圖片格式損毀"])
      }
      
      print("📸 照片讀取成功，原始大小: \(uiImage.size)")
      
      // ⚠️ 修正重點：圖片壓縮！這是解決 Connection invalidated 的關鍵
      // 強制將長邊縮小到 1024px，並進行 JPEG 壓縮
      guard let compressedImage = uiImage.resize(to: 1024),
            let jpegData = compressedImage.jpegData(compressionQuality: 0.7),
            let finalImage = UIImage(data: jpegData) else {
        throw NSError(domain: "ImageError", code: -3, userInfo: [NSLocalizedDescriptionKey: "圖片壓縮失敗"])
      }
      
      print("📉 壓縮後大小: \(finalImage.size)")
      
      // 2. 呼叫 AI 生成
      let generator = AIGenerator()
      let generatedCards = try await generator.generateCardsFromImage(image: finalImage)
      
      // 3. 儲存結果
      saveGeneratedCards(generatedCards)
      
    } catch {
      print("🔴 錯誤: \(error.localizedDescription)")
      handleAIError(error)
    }
    
    // 重置選取狀態
    selectedPhotoItem = nil
    isProcessingImage = false
  }
  
  // MARK: - 共用邏輯: 儲存與錯誤處理
  
  @MainActor // 確保 Core Data 操作在主執行緒
  private func saveGeneratedCards(_ cards: [AIGenerator.GeneratedCard]) {
    for cardData in cards {
      // 智慧分類邏輯
      var targetWordSet: WordSet?
      if let userSelected = selectedWordSet {
        targetWordSet = userSelected
      } else {
        let aiDeckName = cardData.deck
        if let existingSet = allWordSets.first(where: { $0.title == aiDeckName }) {
          targetWordSet = existingSet
        } else {
          // 根據您 WordSet 的定義，這裡使用 title 初始化
          let newSet = WordSet(title: aiDeckName)
          modelContext.insert(newSet)
          targetWordSet = newSet
        }
      }
      
      let newCard = Card(
        title: cardData.title,
        content: cardData.content,
        wordSet: targetWordSet,
        kind: .qa
      )
      modelContext.insert(newCard)
    }
    
    try? modelContext.save()
    
    let feedback = UINotificationFeedbackGenerator()
    feedback.notificationOccurred(.success)
    
#if os(iOS)
    if let defaults = UserDefaults(suiteName: AppGroup.identifier) {
      print("🟢 App writing (AI generated) to shared UserDefaults (AppGroup): \(AppGroup.identifier)")
      do {
        let descriptor = FetchDescriptor<Card>(sortBy: [SortDescriptor(\Card.createdAt, order: .forward)])
        let allCards = try modelContext.fetch(descriptor)
        let selected: [Card] = allCards.count <= 5 ? allCards : Array(allCards.shuffled().prefix(5))
        let ids = selected.map { $0.id.uuidString }
        defaults.set(ids, forKey: "widget.selectedCardIDs")
        defaults.set(0, forKey: "widget.currentCardIndex")
        
        var cachedArray: [[String: String]] = []
        for c in selected {
          cachedArray.append([
            "id": c.id.uuidString,
            "title": c.title,
            "content": c.content,
            "wordSetTitle": c.wordSet?.title ?? ""
          ])
        }
        defaults.set(cachedArray, forKey: "widget.cachedCards")
        defaults.synchronize()
        
        // read-back verification
        if let cached = defaults.array(forKey: "widget.cachedCards") as? [[String: String]] {
          print("✅ (AI) widget.cachedCards written successfully, count: \(cached.count)")
        } else {
          print("⚠️ (AI) widget.cachedCards read-back is nil after write")
        }
        
        if let idsRead = defaults.array(forKey: "widget.selectedCardIDs") as? [String] {
          print("✅ (AI) widget.selectedCardIDs written successfully, count: \(idsRead.count)")
        } else {
          print("⚠️ (AI) widget.selectedCardIDs read-back is nil after write")
        }
        
      } catch {
        print("🔴 (AI) Failed to prepare widget cached cards: \(error)")
        defaults.removeObject(forKey: "widget.selectedCardIDs")
        defaults.set(0, forKey: "widget.currentCardIndex")
        defaults.removeObject(forKey: "widget.cachedCards")
        defaults.synchronize()
      }
    } else {
      print("❌ (AI) UserDefaults(suiteName:) returned nil — App Group not available: \(AppGroup.identifier)")
    }
    
    if #available(iOS 16.0, *) {
      Task {
        try? await Task.sleep(nanoseconds: 500_000_000)
        WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
      }
    }
#endif
    
    dismiss()
  }
  
  private func handleAIError(_ error: Error) {
    aiErrorMessage = error.localizedDescription
    showAIError = true
  }
}

// MARK: - 圖片壓縮擴充功能 (解決 Connection invalidated 錯誤)
// 您可以把這個 Extension 放在這個檔案最下面，或是獨立一個檔案
extension UIImage {
  func resize(to maxDimension: CGFloat) -> UIImage? {
    let aspectRatio = size.width / size.height
    var newSize: CGSize
    
    if size.width > size.height {
      newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
    } else {
      newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
    }
    
    // 如果原本圖片就比較小，不需放大，直接回傳原圖
    if size.width <= maxDimension && size.height <= maxDimension {
      return self
    }
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    draw(in: CGRect(origin: .zero, size: newSize))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage
  }
}
