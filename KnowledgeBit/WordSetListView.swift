// WordSetListView.swift
// List view showing all word sets/decks

import SwiftUI
import SwiftData
import WidgetKit

struct WordSetListView: View {
  @Query(sort: \WordSet.createdAt, order: .reverse) private var wordSets: [WordSet]
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var authService: AuthService
  @State private var showingAddWordSetSheet = false

  var body: some View {
    VStack(spacing: 0) {
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
      }
    }
    .navigationTitle("單字集")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(action: { showingAddWordSetSheet = true }) {
          Label("新增單字集", systemImage: "plus")
        }
      }
    }
    .sheet(isPresented: $showingAddWordSetSheet) {
      AddWordSetView()
        .environmentObject(authService)
    }
  }

  private func deleteWordSets(offsets: IndexSet) {
    let idsToDelete = offsets.map { wordSets[$0].id }
    withAnimation {
      for index in offsets {
        modelContext.delete(wordSets[index])
      }
      do {
        try modelContext.save()
        WidgetReloader.reloadAll()
        if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
          Task {
            for id in idsToDelete {
              await sync.deleteWordSet(id: id)
            }
          }
        }
      } catch {
        print("❌ Failed to delete word set: \(error.localizedDescription)")
      }
    }
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

