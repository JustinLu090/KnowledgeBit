// WordSetIconView.swift
// Minimal icon renderer used by AddWordSetView preview

import SwiftUI

struct WordSetIconView: View {
  let wordSet: WordSet
  var size: CGFloat = 48
  var cornerRadius: CGFloat = 12

  var body: some View {
    Group {
      switch wordSet.iconType ?? .emoji {
      case .emoji:
        ZStack {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.secondarySystemBackground))
          Text(wordSet.iconEmoji ?? "📘")
            .font(.system(size: size * 0.6))
        }
      case .image:
        if let data = wordSet.iconImageData, let uiImg = UIImage(data: data) {
          Image(uiImage: uiImg)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
          ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .fill(Color(.secondarySystemBackground))
            Image(systemName: "photo")
              .imageScale(.large)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .frame(width: size, height: size)
  }
}

#Preview("WordSetIconView") {
  let ws = WordSet(title: "Preview")
  ws.iconType = .emoji
  ws.iconEmoji = "📗"
  return WordSetIconView(wordSet: ws, size: 60, cornerRadius: 16)
}

