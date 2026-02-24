//
//  PremiumListCards.swift
//  KnowledgeBit
//
//  Premium card rows for lists (QA shows title + shortAnswer).
//

import SwiftUI

// MARK: - Press Style (Premium feel)

struct PremiumPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
      .opacity(configuration.isPressed ? 0.95 : 1.0)
      .animation(.spring(response: 0.28, dampingFraction: 0.86), value: configuration.isPressed)
  }
}

// MARK: - Premium Card Container

struct PremiumRowCard<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme

  let tint: Color
  let content: Content

  init(tint: Color = .accentColor, @ViewBuilder content: () -> Content) {
    self.tint = tint
    self.content = content()
  }

  var body: some View {
    ZStack(alignment: .leading) {
      // Base card
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(.ultraThinMaterial)
        .background(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(baseGradient)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 20, x: 0, y: 12)

      // Left accent bar
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(neutralAccentGradient)
        .frame(width: 5)
        .padding(.leading, 12)
        .padding(.vertical, 14)
        .opacity(colorScheme == .dark ? 0.70 : 0.90)

      // Content
      content
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .padding(.leading, 10) // make space for accent bar
    }
  }

  private var borderColor: Color {
    Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10)
  }

  private var shadowColor: Color {
    Color.black.opacity(colorScheme == .dark ? 0.35 : 0.10)
  }


  private var neutralAccentGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.12),
        Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06),
        Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.03)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private var baseGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.05),
        Color.primary.opacity(0.00)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var accentGradient: LinearGradient {
    LinearGradient(
      colors: [
        tint.opacity(colorScheme == .dark ? 0.90 : 0.95),
        tint.opacity(colorScheme == .dark ? 0.40 : 0.55),
        tint.opacity(0.05)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}

// MARK: - Card Row (inside a WordSet)

struct PremiumCardRowView: View {
  @Environment(\.colorScheme) private var colorScheme
  let card: Card

  var body: some View {
    PremiumRowCard(tint: tintColor) {
      HStack(alignment: .center, spacing: 14) {
        iconBlock

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(card.title)
              .font(.headline.weight(.semibold))
              .foregroundStyle(.primary)
              .lineLimit(card.kind == .quote ? 2 : 1)

            Spacer(minLength: 0)

            typeBadge
          }

          if card.kind == .quote {
            Text("點進去查看語錄卡片")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          } else {
            let preview = shortAnswerPreview(card: card)
            if !preview.isEmpty {
              Text(preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .lineSpacing(3)
            } else {
              Text("（尚未填寫簡答）")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
        }

        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
          .padding(.leading, 6)
      }
    }
  }

  private var tintColor: Color {
    card.kind == .quote ? Color.purple : Color.accentColor
  }

  private var typeBadge: some View {
    Text(card.kind == .quote ? "語錄" : "QA")
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        Capsule(style: .continuous)
          .fill(Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.10))
      )
  }

  // ✅ 這裡改：QA 卡用單字集 icon；語錄卡才用 quote icon
  private var iconBlock: some View {
    Group {
      if card.kind == .quote {
        ZStack {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  Color.purple.opacity(colorScheme == .dark ? 0.70 : 0.85),
                  Color.purple.opacity(colorScheme == .dark ? 0.35 : 0.55),
                  Color.black.opacity(colorScheme == .dark ? 0.10 : 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08), lineWidth: 1)
            )

          Image(systemName: "quote.bubble.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white.opacity(colorScheme == .dark ? 0.92 : 0.95))
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .frame(width: 46, height: 46)
      } else {
        // QA：用單字集 icon
        WordSetIconView(wordSet: card.wordSet, size: 46, cornerRadius: 16)
      }
    }
  }

  // MARK: - Preview logic (QA shows shortAnswer)

  private func shortAnswerPreview(card: Card) -> String {
    let sa = card.shortAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
    if !sa.isEmpty { return cleanPreview(from: sa) }

    let fallback = firstNonEmptyLine(from: card.content)
    return cleanPreview(from: fallback)
  }

  private func firstNonEmptyLine(from text: String) -> String {
    let lines = text
      .replacingOccurrences(of: "\r", with: "")
      .components(separatedBy: "\n")

    return lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private func cleanPreview(from markdown: String) -> String {
    var s = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return "" }

    let removals: [String] = ["**", "__", "`", "#", ">", "*", "[", "]", "(", ")", "_"]
    removals.forEach { s = s.replacingOccurrences(of: $0, with: "") }

    if s.hasPrefix("- ") { s.removeFirst(2) }
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)

    if s.count > 92 {
      let idx = s.index(s.startIndex, offsetBy: 92)
      return String(s[..<idx]) + "…"
    }
    return s
  }
}


// MARK: - WordSet Row (optional)

struct PremiumWordSetRowView: View {
  @Environment(\.colorScheme) private var colorScheme
  let wordSet: WordSet

  var body: some View {
    PremiumRowCard(tint: .accentColor) {   // 這個 tint 只影響左側細條 accent，不影響 icon 底色
      HStack(alignment: .center, spacing: 14) {

        // ✅ 改成用 WordSetIconView（你已經把它改為灰底）
        WordSetIconView(wordSet: wordSet, size: 46, cornerRadius: 16)

        VStack(alignment: .leading, spacing: 8) {
          Text(wordSet.title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Text("共 \(wordSet.cards.count) 張卡片")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
    }
  }
}
