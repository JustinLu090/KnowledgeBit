// AIService.swift
// 透過 Supabase Edge Function 呼叫 Google Gemini 產生多張單字卡與選擇題，API Key 存放在 Supabase Secrets。

import Foundation
import Supabase
import SwiftData

/// 單張 AI 產生的單字卡（與 Edge Function 回傳的陣列元素對應）
struct GeneratedCardItem: Decodable {
  let word: String
  let definition: String
  let example_sentence: String

  /// 轉成 Card 用的內容（定義 + 例句，純文字標題不含 Markdown 符號）
  var markdownContent: String {
    var parts: [String] = []
    if !definition.isEmpty { parts.append("定義\n\n\(definition)") }
    if !example_sentence.isEmpty { parts.append("例句\n\n\(example_sentence)") }
    return parts.isEmpty ? "(無內容)" : parts.joined(separator: "\n\n")
  }
}

/// Edge Function 回傳格式：多張單字卡陣列
struct GenerateCardsResponse: Decodable {
  let cards: [GeneratedCardItem]
}

/// 送給 generate-card 的請求 body（傳入現有單字可減少重複產生）
private struct GenerateCardBody: Encodable {
  let prompt: String
  let existing_words: [String]?
}

/// 單題選擇題（挖空句 + 四選一 + 詳解），與 generate-quiz 回傳格式對應
struct ChoiceQuestion: Decodable {
  let sentence_with_blank: String
  let correct_answer: String
  let options: [String]
  /// 詳解：為何正確、干擾項為何錯誤、語法或單字補充（由 AI 產生）
  let explanation: String?
}

/// generate-quiz 回傳格式
struct GenerateQuizResponse: Decodable {
  let questions: [ChoiceQuestion]
}

/// 送給 generate-quiz 的單筆單字
struct QuizWordPayload: Encodable {
  let word: String
  let definition: String?
}

/// generate-quiz 請求 body
struct GenerateQuizRequest: Encodable {
  let words: [QuizWordPayload]
  /// 選填：單字集目標語言（如 "日文"、"韓文"、"英文"），供 AI 出題語言對應
  let word_set: WordSetLanguagePayload?
}

struct WordSetLanguagePayload: Encodable {
  let language: String
}

@MainActor
final class AIService {
  private let client: SupabaseClient

  init(client: SupabaseClient) {
    self.client = client
  }

  /// 根據主題產生多張單字卡，歸於同一單字集使用。
  /// 網路不穩時會自動重試最多 3 次（間隔 2 秒）。
  /// - Parameters:
  ///   - prompt: 使用者輸入的主題或描述，例如「餐廳用餐」「旅行必備單字」
  ///   - existingWords: 單字集內已存在的單字（會傳給 API 避免重複產生）；建議傳小寫以利比對
  /// - Returns: 多張單字卡，每張含 word、definition、example_sentence，可 map 成 Card
  func generateCards(prompt: String, existingWords: [String] = []) async throws -> [GeneratedCardItem] {
    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw AIServiceError.emptyPrompt
    }

    let normalizedExisting = existingWords
      .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
      .filter { !$0.isEmpty }
    let body = GenerateCardBody(
      prompt: trimmed,
      existing_words: normalizedExisting.isEmpty ? nil : normalizedExisting
    )
    let options = FunctionInvokeOptions(body: body)
    let maxAttempts = 3
    let retryDelay: UInt64 = 2_000_000_000 // 2 seconds

    var lastError: Error?
    for attempt in 1...maxAttempts {
      do {
        let response: GenerateCardsResponse = try await client.functions.invoke(
          "generate-card",
          options: options
        )
        return response.cards
      } catch {
        lastError = error
        let isRetryableNetworkError: Bool = {
          if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .timedOut, .notConnectedToInternet:
              return true
            default:
              return false
            }
          }
          return false
        }()
        if isRetryableNetworkError, attempt < maxAttempts {
          print("[AIService] generateCards 網路錯誤，\(attempt)/\(maxAttempts) 秒後重試: \(error.localizedDescription)")
          try? await Task.sleep(nanoseconds: retryDelay)
          continue
        }
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
    if let urlError = lastError as? URLError {
      throw AIServiceError.network(urlError)
    }
    throw AIServiceError.invokeFailed(lastError ?? NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
  }

  /// 依單字集（卡片）產生選擇題：挖空句 + 四選一。
  /// - Parameters:
  ///   - cards: 單字集的卡片（至少 2 張較佳）
  ///   - targetLanguage: 選填，單字集目標語言（如 "日文"、"韓文"），與單字集標題一致時可傳入以確保出題語言正確
  /// - Returns: 題目陣列，每題含 sentence_with_blank、correct_answer、options（4 個）
  func generateQuizQuestions(cards: [Card], targetLanguage: String? = nil) async throws -> [ChoiceQuestion] {
    guard cards.count >= 1 else {
      throw AIServiceError.insufficientCards
    }
    let words = cards.prefix(30).map { card -> QuizWordPayload in
      let def = card.content
        .split(separator: "\n")
        .first
        .map(String.init)
        .map { $0.trimmingCharacters(in: .whitespaces) }
      let definition: String? = def.flatMap { d in d.isEmpty ? nil : String(d.prefix(300)) }
      return QuizWordPayload(word: card.title, definition: definition)
    }
    let lang = (targetLanguage ?? "").trimmingCharacters(in: .whitespaces)
    let wordSetPayload: WordSetLanguagePayload? = lang.isEmpty ? nil : WordSetLanguagePayload(language: lang)
    let request = GenerateQuizRequest(words: words, word_set: wordSetPayload)
    let options = FunctionInvokeOptions(body: request)

    do {
      let response: GenerateQuizResponse = try await client.functions.invoke("generate-quiz", options: options)
      return response.questions
    } catch {
      print("[AIService] generateQuizQuestions failed: \(error)")
      if let body = Self.extractResponseBody(from: error) { print("[AIService] Response body: \(body)") }
      if let urlError = error as? URLError { throw AIServiceError.network(urlError) }
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
  case insufficientCards
  case network(URLError)
  case invokeFailed(Error)

  var errorDescription: String? {
    switch self {
    case .emptyPrompt:
      return "請輸入主題或描述"
    case .insufficientCards:
      return "至少需要一張單字卡才能產生題目"
    case .network(let urlError):
      return "網路錯誤：\(urlError.localizedDescription)"
    case .invokeFailed(let error):
      return "AI 產生失敗：\(error.localizedDescription)"
    }
  }
}
