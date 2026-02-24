//
//  FlashcardView.swift
//  KnowledgeBit
//
//  Flashcard UI (tap to reveal/hide)
//

import SwiftUI

struct FlashcardView: View {
  let card: Card
  @Binding var isRevealed: Bool

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      cardSurface

      VStack(spacing: 0) {
        header
          .padding(.horizontal, 18)
          .padding(.top, 16)

        Spacer(minLength: 12)

        content
          .padding(.horizontal, 18)

        Spacer(minLength: 12)

        footer
          .padding(.horizontal, 18)
          .padding(.bottom, 16)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 430)
    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .onTapGesture {
      HapticFeedbackHelper.light()
      withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
        isRevealed.toggle()
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(isRevealed ? "答案" : "問題")
  }

  // MARK: - Surface

  private var cardSurface: some View {
    let corner: CGFloat = 28

    return RoundedRectangle(cornerRadius: corner, style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay(
        RoundedRectangle(cornerRadius: corner, style: .continuous)
          .strokeBorder(borderColor, lineWidth: 1)
      )
      .background(
        RoundedRectangle(cornerRadius: corner, style: .continuous)
          .fill(softGradient)
      )
      .shadow(color: shadowColor, radius: 18, x: 0, y: 10)
  }

  private var softGradient: LinearGradient {
    // very subtle gradient to add depth
    LinearGradient(
      colors: [
        Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.05),
        Color.primary.opacity(0.00)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var borderColor: Color {
    Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.10)
  }

  private var shadowColor: Color {
    Color.black.opacity(colorScheme == .dark ? 0.35 : 0.10)
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 10) {
      pill(isRevealed ? "ANSWER" : "QUESTION", systemImage: isRevealed ? "lightbulb.fill" : "questionmark.circle.fill")

      if let setTitle = card.wordSet?.title, !setTitle.isEmpty {
        Text(setTitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      srsBadge(level: card.srsLevel)
    }
  }

  private func pill(_ text: String, systemImage: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.caption.weight(.semibold))
      Text(text)
        .font(.caption.weight(.semibold))
        .tracking(0.4)
    }
    .foregroundStyle(.primary.opacity(0.9))
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      Capsule(style: .continuous)
        .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
    )
  }

  private func srsBadge(level: Int) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "sparkles")
        .font(.caption2.weight(.semibold))
      Text("SRS \(max(0, level))")
        .font(.caption2.weight(.semibold))
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      Capsule(style: .continuous)
        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.14 : 0.10))
    )
  }

  // MARK: - Content

  private var content: some View {
    Group {
      if isRevealed {
        answerContent
      } else {
        questionContent
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var questionContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(card.title)
        .font(.system(size: 38, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)
        .lineLimit(4)
        .minimumScaleFactor(0.75)

      Divider()
        .opacity(0.7)

      Text("點一下顯示答案")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  private var answerContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(card.title)
        .font(.title3.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(2)

      Divider()
        .opacity(0.7)

      ScrollView(showsIndicators: false) {
        Text(.init(card.content))
          .font(.system(size: 18, weight: .regular))
          .foregroundStyle(.primary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 2)
      }
    }
  }

  // MARK: - Footer

  private var footer: some View {
    HStack {
      Text(isRevealed ? "點一下收回" : "點一下翻面")
        .font(.footnote)
        .foregroundStyle(.secondary)

      Spacer()

      if let dueText = dueRelativeText(date: card.dueAt) {
        Text(dueText)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func dueRelativeText(date: Date) -> String? {
    let now = Date()
    if date <= now {
      return "已到期"
    }
    let seconds = Int(date.timeIntervalSince(now))
    if seconds < 60 * 60 {
      let m = max(1, seconds / 60)
      return "\(m) 分鐘後"
    }
    if seconds < 60 * 60 * 24 {
      let h = max(1, seconds / 3600)
      return "\(h) 小時後"
    }
    let d = max(1, seconds / (3600 * 24))
    return "\(d) 天後"
  }
}

// MARK: - Preview

#Preview {
  let ws = WordSet(title: "Demo Set", level: "初級")
  let c = Card(title: "serendipity", content: "A happy accident.\n\n- Example: I found it by **serendipity**.", wordSet: ws)
  return FlashcardView(card: c, isRevealed: .constant(false))
    .padding()
    .background(Color(.systemGroupedBackground))
}
