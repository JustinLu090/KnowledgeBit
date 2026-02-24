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
    ZStack {
      Color(.systemGroupedBackground)
        .ignoresSafeArea()

      content
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
    .safeAreaInset(edge: .bottom) { bottomCTA }
    .fullScreenCover(isPresented: $showingQuiz) {
      QuizView(cards: cards)
        .environmentObject(taskService)
        .environmentObject(experienceStore)
        .environmentObject(questService)
    }
  }

  private var content: some View {
    Group {
      if cards.isEmpty {
        ContentUnavailableView(
          "尚無單字",
          systemImage: "tray.fill",
          description: Text("點擊右上角 + 新增單字到此單字集")
        )
        .padding()
      } else {
        ScrollView {
          LazyVStack(spacing: 14) {
            ForEach(cards) { card in
              NavigationLink {
                CardDetailView(card: card)
              } label: {
                PremiumCardRowView(card: card)
              }
              .buttonStyle(.plain)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                  deleteCard(card)
                } label: {
                  Label("刪除", systemImage: "trash")
                }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 10)
          .padding(.bottom, 90) // avoid bottom CTA overlap
        }
      }
    }
  }

  private var bottomCTA: some View {
    Group {
      if !cards.isEmpty {
        Button(action: { showingQuiz = true }) {
          HStack(spacing: 10) {
            Image(systemName: "play.fill")
              .font(.headline.weight(.semibold))
            Text("開始測驗")
              .font(.headline.weight(.semibold))
          }
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .foregroundStyle(.white)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(Color.accentColor)
          )
          .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.thinMaterial)
      }
    }
  }

  private func deleteCard(_ card: Card) {
    withAnimation {
      modelContext.delete(card)

      do {
        try modelContext.save()
        WidgetReloader.reloadAll()
      } catch {
        print("❌ Failed to delete card: \(error.localizedDescription)")
      }
    }
  }
}
