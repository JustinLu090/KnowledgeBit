// WordSetListView.swift
// List view showing all word sets/decks

import SwiftUI
import SwiftData
import WidgetKit

struct WordSetListView: View {
  @Query(sort: \WordSet.createdAt, order: .reverse) private var wordSets: [WordSet]
  @Environment(\.modelContext) private var modelContext
  @State private var showingAddWordSetSheet = false

  var body: some View {
    ZStack {
      Color(.systemGroupedBackground)
        .ignoresSafeArea()

      Group {
        if wordSets.isEmpty {
          ContentUnavailableView(
            "尚無單字集",
            systemImage: "book.closed",
            description: Text("點擊右上角 + 建立第一個單字集")
          )
          .padding()
        } else {
          ScrollView {
            LazyVStack(spacing: 14) {
              ForEach(wordSets) { wordSet in
                NavigationLink {
                  WordSetDetailView(wordSet: wordSet)
                } label: {
                  PremiumWordSetRowView(wordSet: wordSet)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                  Button(role: .destructive) {
                    deleteWordSet(wordSet)
                  } label: {
                    Label("刪除", systemImage: "trash")
                  }
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
          }
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
    }
  }

  private func deleteWordSet(_ wordSet: WordSet) {
    withAnimation {
      modelContext.delete(wordSet)

      do {
        try modelContext.save()
        WidgetReloader.reloadAll()
      } catch {
        print("❌ Failed to delete word set: \(error.localizedDescription)")
      }
    }
  }
}
