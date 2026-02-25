//
//  PremiumCardRowView.swift
//  KnowledgeBit
//
//  Created by JustinLu on 2026/2/26.
//


// PremiumCardRowView.swift

import SwiftUI

struct PremiumCardRowView: View {
  let card: Card

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(card.title)
          .font(.headline.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(2)

        Spacer(minLength: 8)

        if card.isMastered {
          Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(.green)
            .accessibilityLabel("已精通")
        }
      }

      Text(shortAnswerPreview)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      HStack(spacing: 8) {
        Label("SRS Lv \(card.srsLevel)", systemImage: "clock")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        if card.dueAt <= Date() {
          Text("到期")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.orange.opacity(0.15)))
        }
      }
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

  private var shortAnswerPreview: String {
    let s = card.shortAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
    if !s.isEmpty { return s }

    // fallback to first non-empty line of detailed content
    let lines = card.content.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
    let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
    let cleaned = first.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "（尚未填寫簡答）" : cleaned
  }
}