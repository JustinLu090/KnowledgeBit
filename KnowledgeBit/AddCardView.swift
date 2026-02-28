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
  private func generateCardsWithAI() async {
    aiErrorMessage = nil
    isAIGenerating = true
    defer { isAIGenerating = false }

    print("[AddCardView] AI generate: isLoggedIn=\(authService.isLoggedIn)")

    let service = AIService(client: authService.getClient())
    do {
      let items = try await service.generateCards(prompt: aiPrompt)
      guard !items.isEmpty else {
        aiErrorMessage = "未產生任何單字卡，請換個主題再試"
        return
      }

      // 決定要加入的單字集：已選 > 進入時帶入 > 依主題新建
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

      var createdCards: [Card] = []
      for item in items {
        let card = Card(
          title: item.word,
          content: item.markdownContent,
          wordSet: targetSet
        )
        modelContext.insert(card)
        createdCards.append(card)
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
