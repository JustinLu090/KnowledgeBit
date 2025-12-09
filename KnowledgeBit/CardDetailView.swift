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
