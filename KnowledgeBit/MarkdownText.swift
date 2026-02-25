// MarkdownText.swift
// Lightweight Markdown renderer for SwiftUI without external dependencies.

import SwiftUI

struct MarkdownText: View {
  let markdown: String
  let font: Font

  init(markdown: String, font: Font = .body) {
    self.markdown = markdown
    self.font = font
  }

  var body: some View {
    if #available(iOS 15.0, macOS 12.0, *) {
      // Try to render as Markdown -> AttributedString
      if let attributed = try? AttributedString(
        markdown: markdown,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
      ) {
        Text(attributed)
          .font(font)
          .textSelection(.enabled)
      } else {
        Text(markdown)
          .font(font)
          .textSelection(.enabled)
      }
    } else {
      Text(markdown)
        .font(font)
    }
  }
}