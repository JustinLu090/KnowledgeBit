// AppError.swift
// 統一的錯誤型別，配合 ErrorBannerModifier 透過 .handleAppError 顯示。

import Foundation

enum AppError: LocalizedError {
  case networkError(Error)
  case databaseError(String)
  case authError
  case unknown

  var errorDescription: String? {
    switch self {
    case .networkError(let error):
      return "網路錯誤：\(error.localizedDescription)"
    case .databaseError(let message):
      return "資料庫錯誤：\(message)"
    case .authError:
      return "登入驗證失敗，請重新登入"
    case .unknown:
      return "發生未知錯誤，請稍後再試"
    }
  }
}
