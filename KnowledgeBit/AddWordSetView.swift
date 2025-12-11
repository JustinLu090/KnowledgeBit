// AddWordSetView.swift
// View for creating a new word set

import SwiftUI
import SwiftData
import WidgetKit

struct AddWordSetView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss
  
  @State private var title = ""
  @State private var selectedLevel: String? = nil
  
  let levels = ["初級", "中級", "高級"]
  
  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("基本資訊")) {
          TextField("標題（例如：韓文第六課）", text: $title)
          
          Picker("等級", selection: $selectedLevel) {
            Text("無").tag(nil as String?)
            ForEach(levels, id: \.self) { level in
              Text(level).tag(level as String?)
            }
          }
        }
      }
      .navigationTitle("新增單字集")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("儲存") {
            let newWordSet = WordSet(
              title: title,
              level: selectedLevel
            )
            modelContext.insert(newWordSet)
            
            // Save to SwiftData
            do {
              try modelContext.save()
              // Reload widget after successful save
              WidgetReloader.reloadAll()
              dismiss()
            } catch {
              print("❌ Failed to save word set: \(error.localizedDescription)")
            }
          }
          .disabled(title.isEmpty)
        }
      }
    }
  }
}

