// CardDetailView.swift
import SwiftUI

struct CardDetailView: View {
  let card: Card

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(card.title)
          .font(.largeTitle)
          .bold()

        Divider()

        Text(card.content)
          .font(.body)
        // 這裡暫時用 Text，未來可以換成 MarkdownView 渲染庫

        Spacer()
      }
      .padding()
    }
    .navigationTitle(card.deck)
#if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
#endif
  }
}
