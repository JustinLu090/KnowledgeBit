// AddCardView.swift
import SwiftUI
import SwiftData
import WidgetKit

struct AddCardView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss

  // Optional card for edit mode
  var cardToEdit: Card?
  // Optional word set to assign card to
  var wordSet: WordSet?
  
  @Query(sort: \WordSet.title) private var allWordSets: [WordSet]
  
  @State private var title = ""
  @State private var content = ""
  @State private var selectedWordSet: WordSet?
  
  // Computed property to determine if we're in edit mode
  private var isEditMode: Bool {
    cardToEdit != nil
  }

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("基本資訊")) {
          TextField("標題 (例如：Knowledge)", text: $title)
        }
        
        Section(header: Text("單字集")) {
          Picker("選擇單字集", selection: $selectedWordSet) {
            Text("無").tag(nil as WordSet?)
            ForEach(allWordSets, id: \.id) { wordSet in
              Text(wordSet.title).tag(wordSet as WordSet?)
            }
          }
        }

        Section(header: Text("詳細筆記 (Markdown)")) {
          TextEditor(text: $content)
            .frame(height: 200)
        }
      }
      .navigationTitle(isEditMode ? "編輯卡片" : "新增卡片")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("儲存") {
            if let card = cardToEdit {
              // Edit mode: update existing card
              card.title = title
              card.content = content
              card.wordSet = selectedWordSet ?? wordSet
            } else {
              // Add mode: create new card
              let newCard = Card(
                title: title,
                content: content,
                wordSet: selectedWordSet ?? wordSet
              )
              modelContext.insert(newCard)
            }
            
            // Save to SwiftData
            do {
              try modelContext.save()
              // Reload widget after successful save
              WidgetReloader.reloadAll()
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
}
