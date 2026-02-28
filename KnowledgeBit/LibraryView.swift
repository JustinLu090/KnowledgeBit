// LibraryView.swift
// Library tab view for word sets management

import SwiftUI
import SwiftData

struct LibraryView: View {
  @EnvironmentObject private var authService: AuthService
  @EnvironmentObject private var pendingBattleOpenStore: PendingBattleOpenStore
  @Environment(\.modelContext) private var modelContext
  @State private var wordSetToPresent: WordSet?

  var body: some View {
    NavigationStack {
      WordSetListView(currentUserId: authService.currentUserId)
        .navigationTitle("單字集")
        .navigationBarTitleDisplayMode(.large)
    }
    .task {
      await syncSharedWordSetsIfNeeded()
    }
    .onChange(of: pendingBattleOpenStore.wordSetIdToOpen) { _, id in
      guard let id = id else { return }
      fetchAndPresentWordSet(id: id)
    }
    .sheet(isPresented: Binding(
      get: { wordSetToPresent != nil },
      set: { if !$0 { wordSetToPresent = nil; pendingBattleOpenStore.clearWordSetIdToOpen() } }
    )) {
      if let ws = wordSetToPresent {
        WordSetDetailView(wordSet: ws)
          .environmentObject(authService)
      }
    }
  }

  private func fetchAndPresentWordSet(id: UUID) {
    var descriptor = FetchDescriptor<WordSet>(predicate: #Predicate<WordSet> { $0.id == id })
    descriptor.fetchLimit = 1
    guard let fetched = try? modelContext.fetch(descriptor).first else { return }
    wordSetToPresent = fetched
  }

  /// 從 Supabase 載入目前使用者能看到的 word_sets（擁有者 + 共編），若本機尚無則建立一筆。
  private func syncSharedWordSetsIfNeeded() async {
    guard let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) else { return }
    await sync.pullVisibleWordSetsAndMergeToLocal(modelContext: modelContext)
  }
}

