// View+HandleAppError.swift
// 全域便利方法：呼叫 .handleAppError(Binding<String?>) 即可掛上錯誤 Banner。

import SwiftUI

extension View {
  /// 綁定錯誤訊息文字；非 nil 時於畫面頂端顯示紅色 Banner，數秒後自動消失。
  /// 通常於 ViewModel 中將 `AppError.errorDescription` 寫入該 Binding。
  func handleAppError(_ errorMessage: Binding<String?>) -> some View {
    modifier(ErrorBannerModifier(errorMessage: errorMessage))
  }
}
