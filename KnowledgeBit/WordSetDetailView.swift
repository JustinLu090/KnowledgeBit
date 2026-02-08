// WordSetDetailView.swift
// Detail view showing cards in a word set and quiz option

import SwiftUI
import SwiftData
import WidgetKit

struct WordSetDetailView: View {
  @Bindable var wordSet: WordSet
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var taskService: TaskService
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var questService: DailyQuestService
  @State private var showingQuiz = false
  
  // Fetch cards for this word set
  private var cards: [Card] {
    wordSet.cards.sorted { $0.createdAt > $1.createdAt }
  }
  
  var body: some View {
    VStack(spacing: 0) {
      if cards.isEmpty {
        ContentUnavailableView(
          "尚無單字",
          systemImage: "tray.fill",
          description: Text("點擊右上角 + 新增單字到此單字集")
        )
        .padding()
      } else {
        List {
          ForEach(cards) { card in
            NavigationLink {
              CardDetailView(card: card)
            }             label: {
              Text(card.title)
                .font(.headline)
            }
          }
          .onDelete(perform: deleteCards)
        }
      }
    }
    .navigationTitle(wordSet.title)
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        NavigationLink {
          AddCardView(wordSet: wordSet)
        } label: {
          Label("新增單字", systemImage: "plus")
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      if !cards.isEmpty {
        Button(action: { showingQuiz = true }) {
          HStack {
            Image(systemName: "play.fill")
            Text("開始測驗")
              .fontWeight(.bold)
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(10)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
      }
    }
    .fullScreenCover(isPresented: $showingQuiz) {
      QuizView(cards: cards)
        .environmentObject(taskService)
        .environmentObject(experienceStore)
        .environmentObject(questService)
    }
  }
  
  private func deleteCards(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(cards[index])
      }
      
      // Save to SwiftData
      do {
        try modelContext.save()
        // Reload widget after successful delete
        WidgetReloader.reloadAll()
      } catch {
        print("❌ Failed to delete card: \(error.localizedDescription)")
      }
    }
  }
}

