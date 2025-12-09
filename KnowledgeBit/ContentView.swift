// ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
  // 1. 告訴 App 我們要查詢 Card 資料
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]

  // 控制新增視窗的開關
  @State private var showingAddCardSheet = false
  @State private var showingSettingsSheet = false

  // ContentView.swift 的 body 修改如下：

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        StatsView()
          .padding(.top)
        NavigationLink(destination: QuizView()) {
          HStack {
            Image(systemName: "play.fill")
            Text("開始每日測驗")
              .fontWeight(.bold)
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(10)
          .padding()
        }

        List {
          ForEach(cards) { card in
            NavigationLink {
              CardDetailView(card: card)
            } label: {

              HStack {
                VStack(alignment: .leading) {
                  Text(card.title)
                    .font(.headline)
                  Text(card.deck)
                    .font(.caption)
                }
              }
            }
          }
          .onDelete(perform: deleteItems)
        }
      }
      .background(Color(UIColor.systemGroupedBackground))
      .navigationTitle("KnowledgeBit")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: { showingSettingsSheet = true }) {
            Label("Settings", systemImage: "gearshape")
          }
        }
        ToolbarItem(placement: .primaryAction) {
          Button(action: { showingAddCardSheet = true }) {
            Label("Add Item", systemImage: "plus")
          }
        }
      }
      .sheet(isPresented: $showingAddCardSheet) {
        AddCardView()
      }
      .sheet(isPresented: $showingSettingsSheet) {
        SettingsView()
      }
    }
  }

  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(cards[index])
      }
    }
  }
}
