// FlipCardView.swift
// 3D flip card view with separate front and back sides to prevent text mirroring

import SwiftUI

/// 依字數調整字卡內文起始字級，搭配 `minimumScaleFactor` 讓長文仍能 fit 固定高度區域。
enum FlashcardTextSizing {
  static func fontSize(for text: String, base: CGFloat) -> CGFloat {
    let count = text.count
    let factor: CGFloat
    switch count {
    case 0 ... 40: factor = 1.0
    case 41 ... 80: factor = 0.92
    case 81 ... 140: factor = 0.82
    case 141 ... 220: factor = 0.72
    default: factor = 0.62
    }
    return max(11, base * factor)
  }
}

struct FlipCardView: View {
  let card: Card
  @Binding var isFlipped: Bool
  /// 翻到背面（顯示答案）時呼叫，供 TTS 朗讀使用
  var onReveal: (() -> Void)? = nil
  
  var body: some View {
    ZStack {
      // FRONT SIDE - Question
      frontView
        .opacity(isFlipped ? 0 : 1)
        .rotation3DEffect(
          .degrees(isFlipped ? 180 : 0),
          axis: (x: 0, y: 1, z: 0),
          perspective: 0.8
        )
      
      // BACK SIDE - Answer
      backView
        .opacity(isFlipped ? 1 : 0)
        .rotation3DEffect(
          .degrees(isFlipped ? 0 : -180),
          axis: (x: 0, y: 1, z: 0),
          perspective: 0.8
        )
    }
    .animation(.spring(), value: isFlipped)
    .onChange(of: isFlipped) { _, newValue in
      if newValue { onReveal?() }
    }
  }

  // MARK: - Front View (Question)
  
  private var frontView: some View {
    ZStack {
      // Background
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.blue.opacity(0.1))
        .shadow(radius: 5)

      VStack(alignment: .leading, spacing: 0) {
        Text("❓ 問題")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
          .padding(.top, 12)
          .padding(.bottom, 8)

        GeometryReader { geo in
          Text(card.title)
            .font(.system(size: FlashcardTextSizing.fontSize(for: card.title, base: 28), weight: .bold))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.32)
            .lineLimit(nil)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
      }
    }
  }
  
  // MARK: - Back View (Answer)
  
  private var backView: some View {
    ZStack {
      // Background (same style as front)
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.blue.opacity(0.1))
        .shadow(radius: 5)

      VStack(alignment: .leading, spacing: 0) {
        Text("💡 答案")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
          .padding(.top, 12)
          .padding(.bottom, 8)

        GeometryReader { geo in
          Text(card.content)
            .font(.system(size: FlashcardTextSizing.fontSize(for: card.content, base: 26), weight: .bold))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.28)
            .lineLimit(nil)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
      }
    }
  }
}

