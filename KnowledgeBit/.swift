//
//  WordSetIconView 2.swift
//  KnowledgeBit
//
//  Created by JustinLu on 2026/2/15.
//


//
//  WordSetIconView.swift
//  KnowledgeBit
//
//  Created by JustinLu on 2026/2/15.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct WordSetIconView: View {
  @Environment(\.colorScheme) private var colorScheme

  let wordSet: WordSet?
  var size: CGFloat = 46
  var cornerRadius: CGFloat = 16

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(backgroundGradient)
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08), lineWidth: 1)
        )

      content
    }
    .frame(width: size, height: size)
  }

  // ✅ 不用 guard + return，改成 if let，保證每個分支都產生 View
  @ViewBuilder
  private var content: some View {
    if let wordSet {
      switch wordSet.iconType {
      case .emoji:
        Text(validEmoji(wordSet.iconEmoji))
          .font(.system(size: size * 0.44))
          .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)

      case .image:
        if let data = wordSet.iconImageData,
           let uiImage = UIImage(data: data) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous))
            .padding(3)
        } else {
          Image(systemName: "photo.fill")
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(Color.white.opacity(colorScheme == .dark ? 0.92 : 0.95))
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
      }
    } else {
      Text("📘")
        .font(.system(size: size * 0.44))
        .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
    }
  }

  private var backgroundGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color.accentColor.opacity(colorScheme == .dark ? 0.65 : 0.85),
        Color.accentColor.opacity(colorScheme == .dark ? 0.30 : 0.50),
        Color.black.opacity(colorScheme == .dark ? 0.10 : 0.06)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private func validEmoji(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "📘" : trimmed
  }
}