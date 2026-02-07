// DefaultAvatarView.swift
// 共用預設頭像（藍紫漸層 + person.fill）

import SwiftUI

struct DefaultAvatarView: View {
  var size: CGFloat = 100
  
  private var iconFontSize: CGFloat { size * 0.5 }
  
  var body: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: [.blue, .purple],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .frame(width: size, height: size)
      .overlay {
        Image(systemName: "person.fill")
          .font(.system(size: iconFontSize))
          .foregroundStyle(.white)
      }
  }
}

#Preview("Small") {
  DefaultAvatarView(size: 100)
}
#Preview("Large") {
  DefaultAvatarView(size: 120)
}
