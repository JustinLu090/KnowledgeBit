// AddWordSetView.swift
// View for creating a new word set

import SwiftUI
import SwiftData
import WidgetKit
import os

struct AddWordSetView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var authService: AuthService

  @State private var title = ""
  @State private var selectedLevel: String? = nil
  @State private var selectedLanguage: String? = nil

  let levels = ["初級", "中級", "高級"]
  let languages: [(label: String, code: String?)] = [
    ("自動偵測", nil),
    ("英文 (en-US)", "en-US"),
    ("日文 (ja-JP)", "ja-JP"),
    ("韓文 (ko-KR)", "ko-KR"),
    ("中文繁體 (zh-TW)", "zh-TW"),
    ("法文 (fr-FR)", "fr-FR"),
    ("德文 (de-DE)", "de-DE"),
    ("西班牙文 (es-ES)", "es-ES"),
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("基本資訊")) {
          TextField("標題（例如：英文）", text: $title)

          Picker("等級", selection: $selectedLevel) {
            Text("無").tag(nil as String?)
            ForEach(levels, id: \.self) { level in
              Text(level).tag(level as String?)
            }
          }

          Picker("語言（TTS / 語音練習）", selection: $selectedLanguage) {
            ForEach(languages, id: \.code) { item in
              Text(item.label).tag(item.code as String?)
            }
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("新增單字集")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("儲存") {
            guard let ownerId = authService.currentUserId else { return }
            let newWordSet = WordSet(
              title: title,
              level: selectedLevel,
              language: selectedLanguage,
              ownerUserId: ownerId
            )
            modelContext.insert(newWordSet)

            do {
              try modelContext.save()
              WidgetReloader.reloadAll()
              if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
                Task { await sync.syncWordSet(newWordSet) }
              }
              dismiss()
            } catch {
              AppLog.wordset.info("❌ Failed to save word set: \(error.localizedDescription)")
            }
          }
          .disabled(title.isEmpty)
        }
      }
    }
  }
}

