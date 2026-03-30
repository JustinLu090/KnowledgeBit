// WordSetListView.swift
// List view showing all word sets/decks

import SwiftUI
import SwiftData
import WidgetKit
import os

struct WordSetListView: View {
  @Query private var wordSets: [WordSet]
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var authService: AuthService
  @State private var showingAddWordSetSheet = false
  @State private var deleteErrorMessage: String?
  @State private var isDeletingWordSet = false

  init(currentUserId: UUID? = nil) {
    // 顯示所有可見單字集（自己建立的 + 被邀請共編的），sync 已只從 get_visible_word_sets 寫入
    _wordSets = Query(sort: \WordSet.createdAt, order: .reverse)
  }

  var body: some View {
    VStack(spacing: 0) {
      CompactPageHeader("單字集") {
        Button {
          showingAddWordSetSheet = true
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color.blue)
            .clipShape(Circle())
            .accessibilityLabel("新增單字集")
        }
        .buttonStyle(.plain)
      }

      if wordSets.isEmpty {
        ContentUnavailableView(
          "尚無單字集",
          systemImage: "book.closed",
          description: Text("點擊右上角 + 建立第一個單字集")
        )
        .padding()
      } else {
        List {
          ForEach(wordSets) { wordSet in
            NavigationLink {
              WordSetDetailView(wordSet: wordSet)
            } label: {
              WordSetRowView(wordSet: wordSet)
            }
          }
          .onDelete(perform: deleteWordSets)
        }
        .listStyle(.plain)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $showingAddWordSetSheet) {
      AddWordSetView()
        .environmentObject(authService)
    }
    .alert("刪除失敗", isPresented: Binding(
      get: { deleteErrorMessage != nil },
      set: { if !$0 { deleteErrorMessage = nil } }
    )) {
      Button("確定", role: .cancel) { deleteErrorMessage = nil }
    } message: {
      Text(deleteErrorMessage ?? "")
    }
  }

  private func deleteWordSets(offsets: IndexSet) {
    let blockedOffsets = offsets.filter { !canDeleteWordSet(wordSets[$0]) }
    if !blockedOffsets.isEmpty {
      deleteErrorMessage = "只有創辦者才能刪除此單字集。"
      return
    }

    let deletableOffsets = offsets.filter { canDeleteWordSet(wordSets[$0]) }
    guard !deletableOffsets.isEmpty else { return }

    let targetWordSets = deletableOffsets.map { wordSets[$0] }
    guard !isDeletingWordSet else { return }

    isDeletingWordSet = true
    Task {
      defer {
        Task { @MainActor in
          isDeletingWordSet = false
        }
      }

      do {
        if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
          for wordSet in targetWordSets {
            try await sync.deleteWordSetOrThrow(id: wordSet.id)
            await MainActor.run {
              modelContext.delete(wordSet)
              do {
                try modelContext.save()
                WidgetReloader.reloadAll()
              } catch {
                deleteErrorMessage = "遠端已刪除，但本機更新失敗，請重新開啟 app 後確認。"
                AppLog.wordset.info("❌ Failed to save local word set deletion: \(error.localizedDescription)")
              }
            }
          }
        } else {
          await MainActor.run {
            withAnimation {
              for wordSet in targetWordSets {
                modelContext.delete(wordSet)
              }
            }
            do {
              try modelContext.save()
              WidgetReloader.reloadAll()
            } catch {
              deleteErrorMessage = "本機刪除失敗，請稍後再試。"
              AppLog.wordset.info("❌ Failed to delete local word set: \(error.localizedDescription)")
            }
          }
        }
      } catch {
        await MainActor.run {
          deleteErrorMessage = error.localizedDescription
        }
      }
    }
  }

  private func canDeleteWordSet(_ wordSet: WordSet) -> Bool {
    guard let currentUserId = authService.currentUserId else { return false }
    return wordSet.ownerUserId == nil || wordSet.ownerUserId == currentUserId
  }
}

// MARK: - Word Set Row View

struct WordSetRowView: View {
  let wordSet: WordSet
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(wordSet.title)
          .font(.title3)
          .bold()
        
        Spacer()
        
        // Level badge
        if let level = wordSet.level {
          Text(level)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(levelColor(for: level))
            .cornerRadius(8)
        }
      }
      
      Text("自訂單字集・共 \(wordSet.cards.count) 個單字")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }
  
  private func levelColor(for level: String) -> Color {
    switch level {
    case "初級":
      return .green
    case "中級":
      return .orange
    case "高級":
      return .red
    default:
      return .gray
    }
  }
}

