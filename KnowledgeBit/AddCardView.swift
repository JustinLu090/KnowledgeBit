// AddCardView.swift
import SwiftUI
import SwiftData

struct AddCardView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss

  @State private var title = ""
  @State private var content = ""
  @State private var selectedDeck = "CS"

  let decks = ["CS", "Japanese", "Physics", "Misc"]

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("基本資訊")) {
          TextField("標題 (例如: TCP)", text: $title)
          Picker("分類", selection: $selectedDeck) {
            ForEach(decks, id: \.self) { deck in
              Text(deck).tag(deck)
            }
          }
        }

        Section(header: Text("詳細筆記 (Markdown)")) {
          TextEditor(text: $content)
            .frame(height: 200)
        }
      }
      .navigationTitle("新增卡片")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("儲存") {
            let newCard = Card(title: title, content: content, deck: selectedDeck)
            modelContext.insert(newCard) // 存入資料庫
            dismiss()
          }
          .disabled(title.isEmpty)
        }
      }
    }
  }
}
