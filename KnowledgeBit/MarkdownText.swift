//
//  MarkdownText.swift
//  KnowledgeBit
//
//  Created by JustinLu on 2026/2/15.
//


//
//  MarkdownText.swift
//  KnowledgeBit
//
//  Render markdown safely with fallback.
//

import SwiftUI

struct MarkdownText: View {
  let markdown: String
  var font: Font = .body
  var foreground: Color? = nil
  var lineSpacing: CGFloat = 4

  var body: some View {
    Group {
      if #available(iOS 15.0, *) {
        if let attributed = try? AttributedString(
          markdown: markdown,
          options: AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
          )
        ) {
          Text(attributed)
        } else {
          Text(markdown)
        }
      } else {
        Text(markdown)
      }
    }
    .font(font)
    .foregroundStyle(foreground ?? .primary)
    .lineSpacing(lineSpacing)
    .textSelection(.enabled)
  }
}