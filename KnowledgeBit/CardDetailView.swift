// CardDetailView.swift
import SwiftUI
import SwiftData

struct CardDetailView: View {
  @Bindable var card: Card
  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var showingEditSheet = false
  @State private var showingDeleteConfirmation = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(card.title)
          .font(.largeTitle)
          .bold()

        Divider()

        Text(card.content)
          .font(.body)

        Spacer()
      }
      .padding()
    }
    .navigationTitle(card.wordSet?.title ?? "卡片")
#if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
#endif
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
            Label("刪除卡片", systemImage: "trash")
          }
          
          Button(action: { showingEditSheet = true }) {
            Label("編輯", systemImage: "pencil")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .sheet(isPresented: $showingEditSheet) {
      AddCardView(cardToEdit: card)
    }
    .confirmationDialog(
      "刪除卡片",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("刪除", role: .destructive) {
        deleteCard()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("確定要刪除「\(card.title)」嗎？此操作無法復原。")
    }
  }
  
  /// Delete the card from SwiftData and dismiss the view
  private func deleteCard() {
    withAnimation {
      modelContext.delete(card)
      do {
        try modelContext.save()
        dismiss()
      } catch {
        print("❌ Failed to delete card: \(error.localizedDescription)")
      }
    }
  }
}
