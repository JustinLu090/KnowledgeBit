// ErrorBannerModifier.swift
// 當 errorMessage 不為 nil 時於畫面頂端顯示紅色警告 Banner，可自動消失或手動關閉。

import SwiftUI

struct ErrorBannerModifier: ViewModifier {
  @Binding var errorMessage: String?
  var autoDismissAfter: Duration = .seconds(3)

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .top) {
        if let message = errorMessage {
          banner(message: message)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: message) {
              try? await Task.sleep(for: autoDismissAfter)
              guard !Task.isCancelled else { return }
              withAnimation(.easeInOut(duration: 0.25)) {
                errorMessage = nil
              }
            }
        }
      }
      .animation(.easeInOut(duration: 0.25), value: errorMessage)
  }

  @ViewBuilder
  private func banner(message: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.white)

      Text(message)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button {
        withAnimation(.easeInOut(duration: 0.25)) {
          errorMessage = nil
        }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white.opacity(0.9))
          .padding(4)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("關閉")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.red.gradient)
    )
    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isStaticText)
  }
}
