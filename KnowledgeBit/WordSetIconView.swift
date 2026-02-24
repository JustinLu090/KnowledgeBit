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
        .fill(backgroundGradient) // ✅ 改成灰色基底
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08), lineWidth: 1)
        )

      content
    }
    .frame(width: size, height: size)
  }

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
            .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.70)) // ✅ 不要白字藍底
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
        }
      }
    } else {
      Text("📘")
        .font(.system(size: size * 0.44))
        .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
    }
  }

  // ✅ 這裡改成灰色系：保留基礎灰底與高級感
  private var backgroundGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.06),
        Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.04),
        Color.black.opacity(colorScheme == .dark ? 0.06 : 0.03)
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
