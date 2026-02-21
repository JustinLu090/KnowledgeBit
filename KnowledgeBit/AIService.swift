// AIService.swift
// 透過 Supabase Edge Function 呼叫 Google Gemini 產生多張單字卡，API Key 存放在 Supabase Secrets，不放在 App 內。

import Foundation
import Supabase

/// 單張 AI 產生的單字卡（與 Edge Function 回傳的陣列元素對應）
struct GeneratedCardItem: Decodable {
  let word: String
  let definition: String
  let example_sentence: String

  /// 轉成 Card 用的 Markdown 內容（定義 + 例句）
  var markdownContent: String {
    var parts: [String] = []
    if !definition.isEmpty { parts.append("**定義**\n\n\(definition)") }
    if !example_sentence.isEmpty { parts.append("**例句**\n\n\(example_sentence)") }
    return parts.isEmpty ? "(無內容)" : parts.joined(separator: "\n\n")
  }
}

/// Edge Function 回傳格式：多張單字卡陣列
struct GenerateCardsResponse: Decodable {
  let cards: [GeneratedCardItem]
}

@MainActor
final class AIService {
  private let client: SupabaseClient

  init(client: SupabaseClient) {
    self.client = client
  }

  /// 根據主題產生多張單字卡，歸於同一單字集使用。
  /// - Parameter prompt: 使用者輸入的主題或描述，例如「餐廳用餐」「旅行必備單字」
  /// - Returns: 多張單字卡，每張含 word、definition、example_sentence，可 map 成 Card
  func generateCards(prompt: String) async throws -> [GeneratedCardItem] {
    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw AIServiceError.emptyPrompt
    }

    let body = ["prompt": trimmed]
    let options = FunctionInvokeOptions(body: body)

    do {
      let response: GenerateCardsResponse = try await client.functions.invoke(
        "generate-card",
        options: options
      )
      return response.cards
    } catch {
      print("[AIService] generateCards failed: \(error)")
      if let ns = error as NSError? {
        print("[AIService] NSError domain=\(ns.domain), code=\(ns.code), userInfo=\(ns.userInfo)")
      }
      if let body = Self.extractResponseBody(from: error) {
        print("[AIService] Response body: \(body)")
      }
      if let urlError = error as? URLError {
        throw AIServiceError.network(urlError)
      }
      throw AIServiceError.invokeFailed(error)
    }
  }

  /// 從 SDK 的 error 裡遞迴找出 Data 並轉成字串（用於印出 502/500 的 response body）
  private static func extractResponseBody(from error: Error) -> String? {
    func findData(_ subject: Any, depth: Int) -> Data? {
      guard depth < 5 else { return nil }
      let m = Mirror(reflecting: subject)
      for child in m.children {
        if let data = child.value as? Data, !data.isEmpty { return data }
        if let nested = findData(child.value, depth: depth + 1) { return nested }
      }
      return nil
    }
    guard let data = findData(error, depth: 0), let s = String(data: data, encoding: .utf8) else { return nil }
    return s
  }
}

enum AIServiceError: LocalizedError {
  case emptyPrompt
  case network(URLError)
  case invokeFailed(Error)

  var errorDescription: String? {
    switch self {
    case .emptyPrompt:
      return "請輸入主題或描述"
    case .network(let urlError):
      return "網路錯誤：\(urlError.localizedDescription)"
    case .invokeFailed(let error):
      return "AI 產生失敗：\(error.localizedDescription)"
    }
  }
}
