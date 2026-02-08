// CardStyle.swift
// 共用卡片樣式：padding、背景、圓角，可選陰影

import SwiftUI
import Combine

struct CardStyle: ViewModifier {
  var withShadow: Bool = false
  
  func body(content: Content) -> some View {
    content
      .padding(20)
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(16)
      .shadow(color: withShadow ? .black.opacity(0.05) : .clear, radius: 8, x: 0, y: 2)
  }
}

extension View {
  func cardStyle(withShadow: Bool = false) -> some View {
    modifier(CardStyle(withShadow: withShadow))
  }
}
