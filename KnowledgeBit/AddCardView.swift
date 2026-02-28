// AddCardView.swift
import SwiftUI
import SwiftData
import WidgetKit

struct AddCardView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var authService: AuthService

  // Optional card for edit mode
  var cardToEdit: Card?
  // Optional word set to assign card to
  var wordSet: WordSet?
  
  @Query(sort: \WordSet.title) private var allWordSets: [WordSet]
  
  @State private var title = ""
  @State private var content = ""
  @State private var selectedWordSet: WordSet?
  
  // AI 生成
  @State private var aiPrompt = ""
  @State private var isAIGenerating = false
  @State private var aiErrorMessage: String?
  
  // Computed property to determine if we're in edit mode
  private var isEditMode: Bool {
    cardToEdit != nil
  }

  var body: some View {
    NavigationStack {
      Form {
        // AI 生成區塊：可輸入一段 prompt（可中英混用），產生多張單字卡
        if !isEditMode {
          Section {
            TextField("描述想學的單字範圍", text: $aiPrompt)
              .disabled(isAIGenerating)
            if let message = aiErrorMessage {
              Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            }
            Button {
              Task { await generateCardsWithAI() }
            } label: {
              HStack {
                if isAIGenerating {
                  ProgressView()
                    .scaleEffect(0.9)
                }
                Text(isAIGenerating ? "產生中…" : "用 AI 產生單字集")
              }
              .frame(maxWidth: .infinity)
            }
            .disabled(aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAIGenerating)
          } header: {
            Text("AI 產生")
          } footer: {
            Text("可輸入一段說明或主題，AI 依內容產生多張單字卡。")
          }
        }

        Section(header: Text("基本資訊")) {
          TextField("標題 (例如：Knowledge)", text: $title)
        }
        

        Section(header: Text("詳細筆記 (Markdown)")) {
          TextEditor(text: $content)
            .frame(height: 200)
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(isEditMode ? "編輯卡片" : "新增卡片")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("儲存") {
            let cardToSync: Card?
            if let card = cardToEdit {
              card.title = title
              card.content = content
              card.wordSet = selectedWordSet ?? wordSet
              cardToSync = card
            } else {
              let newCard = Card(
                title: title,
                content: content,
                wordSet: selectedWordSet ?? wordSet
              )
              modelContext.insert(newCard)
              cardToSync = newCard
            }

            do {
              try modelContext.save()
              WidgetReloader.reloadAll()
              if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService),
                 let card = cardToSync {
                Task {
                  if let ws = card.wordSet { await sync.syncWordSet(ws) }
                  await sync.syncCard(card)
                }
              }
              dismiss()
            } catch {
              print("❌ Failed to save card: \(error.localizedDescription)")
            }
          }
          .disabled(title.isEmpty)
        }
      }
      .onAppear {
        // If editing, populate fields with existing card data
        if let card = cardToEdit {
          title = card.title
          content = card.content
          selectedWordSet = card.wordSet
        } else {
          // If creating new card and wordSet is provided, pre-select it
          selectedWordSet = wordSet
        }
      }
    }
  }

  /// 依主題用 AI 產生多張單字卡，寫入所選單字集（或新建單字集），然後關閉畫面。
  /// 會傳入單字集內已有單字給 API 並在寫入前再過濾，避免與現有或共編者已產生的字卡重複。
  private func generateCardsWithAI() async {
    aiErrorMessage = nil
    isAIGenerating = true
    defer { isAIGenerating = false }

    print("[AddCardView] AI generate: isLoggedIn=\(authService.isLoggedIn)")

    // 先決定目標單字集，才能取得「已存在的單字」供 API 與本機去重
    let targetSet: WordSet
    if let existing = selectedWordSet ?? wordSet {
      targetSet = existing
    } else {
      let setName = String(aiPrompt.prefix(30)).trimmingCharacters(in: .whitespacesAndNewlines)
      let ownerId = authService.currentUserId
      targetSet = WordSet(
        title: setName.isEmpty ? "AI 單字集" : setName,
        ownerUserId: ownerId
      )
      modelContext.insert(targetSet)
    }

    let existingTitlesNormalized = Set(
      targetSet.cards.map { $0.title.trimmingCharacters(in: .whitespaces).lowercased() }
    )

    let service = AIService(client: authService.getClient())
    do {
      let existingWordsForAPI = Array(existingTitlesNormalized)
      let items = try await service.generateCards(prompt: aiPrompt, existingWords: existingWordsForAPI)
      guard !items.isEmpty else {
        aiErrorMessage = "未產生任何單字卡，請換個主題再試"
        return
      }

      // 本機再過濾一次：與現有重複或同批內重複的都不插入
      var seenNormalized = existingTitlesNormalized
      let toInsert = items.filter { item in
        let key = item.word.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty, !seenNormalized.contains(key) else { return false }
        seenNormalized.insert(key)
        return true
      }

      if toInsert.isEmpty {
        aiErrorMessage = "產生的單字與現有字卡重複，未新增任何卡片。請換個主題或單字集再試。"
        return
      }

      var createdCards: [Card] = []
      for item in toInsert {
        let card = Card(
          title: item.word.trimmingCharacters(in: .whitespaces),
          content: item.markdownContent,
          wordSet: targetSet
        )
        modelContext.insert(card)
        createdCards.append(card)
      }

      let skippedCount = items.count - toInsert.count
      if skippedCount > 0 {
        print("[AddCardView] AI 產生：新增 \(toInsert.count) 張，略過 \(skippedCount) 張重複單字")
      }

      try modelContext.save()
      WidgetReloader.reloadAll()
      if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
        Task {
          await sync.syncWordSet(targetSet)
          for card in createdCards {
            await sync.syncCard(card)
          }
        }
      }
      aiErrorMessage = nil
      dismiss()
    } catch {
      aiErrorMessage = error.localizedDescription
    }
  }
}
