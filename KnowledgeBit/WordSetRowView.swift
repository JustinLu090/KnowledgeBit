//
//  PremiumWordSetRowView.swift
//  KnowledgeBit
//
//  Created by JustinLu on 2026/2/26.
//


// PremiumWordSetRowView.swift

import SwiftUI

struct PremiumWordSetRowView: View {
  let wordSet: WordSet

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // Icon
      ZStack {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.accentColor.opacity(0.12))
          .frame(width: 48, height: 48)

        Image(systemName: "book.closed.fill")
          .foregroundStyle(Color.accentColor)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text(wordSet.title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)

          Spacer(minLength: 8)

          if let level = wordSet.level, !level.isEmpty {
            Text(level)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Capsule().fill(Color.secondary.opacity(0.12)))
          }
        }

        Text("共 \(wordSet.cards.count) 張卡片")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Text(dateText)
          .font(.caption)
          .foregroundStyle(.tertiary)
      }

      Spacer(minLength: 0)
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(.ultraThinMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    )
  }

  private var dateText: String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return "建立於 \(f.string(from: wordSet.createdAt))"
  }
}