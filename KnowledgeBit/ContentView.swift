// ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
  // 1. 告訴 App 我們要查詢 Card 資料
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]

  // 控制新增視窗的開關
  @State private var showingAddCardSheet = false

  // ContentView.swift 的 body 修改如下：

  var body: some View {
    NavigationStack {
      // 1. 改成 VStack，這樣才能放按鈕在列表上面
      VStack(spacing: 20) {
        StatsView()
          .padding(.top)
        // 新增：開始測驗按鈕
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

        // 原本的列表 List
        List {
          ForEach(cards) { card in
            // ... 裡面的程式碼不變 ...
            NavigationLink {
              CardDetailView(card: card)
            } label: {
              // ... 顯示卡片 UI 不變 ...
              HStack {
                VStack(alignment: .leading) {
                  Text(card.title)
                    .font(.headline)
                  Text(card.deck)
                    .font(.caption)
                  // ...
                }
                // ...
              }
            }
          }
          .onDelete(perform: deleteItems)
        }
      }
      .background(Color(UIColor.systemGroupedBackground))
      .navigationTitle("KnowledgeBit")
      .toolbar {
        // ... 工具列按鈕保持不變 ...
        ToolbarItem(placement: .primaryAction) {
          Button(action: { showingAddCardSheet = true }) {
            Label("Add Item", systemImage: "plus")
          }
        }
      }
      .sheet(isPresented: $showingAddCardSheet) {
        AddCardView()
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
