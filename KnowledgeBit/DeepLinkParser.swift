// DeepLinkParser.swift
// Widget / Universal Link 進入 App 時的 URL 解析（與 `KnowledgeBitApp.onOpenURL` 使用）

import Foundation

enum DeepLinkParser {
  /// 解析 Widget 單字卡連結 `knowledgebit://wordSet?wordSetId=XXX`
  static func parseWordSetURL(_ url: URL) -> UUID? {
    guard url.scheme?.lowercased() == "knowledgebit",
          url.host?.lowercased() == "wordset",
          let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let idStr = comps.queryItems?.first(where: { $0.name == "wordSetId" })?.value else { return nil }
    return UUID(uuidString: idStr)
  }

  /// 解析對戰地圖 Widget 連結 `knowledgebit://battle?wordSetId=XXX`
  static func parseBattleURL(_ url: URL) -> UUID? {
    guard url.scheme?.lowercased() == "knowledgebit",
          url.host?.lowercased() == "battle",
          let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let idStr = comps.queryItems?.first(where: { $0.name == "wordSetId" })?.value else { return nil }
    return UUID(uuidString: idStr)
  }

  /// 解析挑戰連結 `knowledgebit://challenge?id=<UUID>`
  static func parseChallengeURL(_ url: URL) -> UUID? {
    guard url.scheme?.lowercased() == "knowledgebit",
          url.host?.lowercased() == "challenge",
          let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let idStr = comps.queryItems?.first(where: { $0.name == "id" })?.value else { return nil }
    return UUID(uuidString: idStr)
  }

  /// 解析邀請連結，回傳 `(invite_code, displayName 可選)`。支援 https 邀請頁與 `knowledgebit://join/XXX`
  static func parseInviteURL(_ url: URL) -> (code: String, displayName: String?)? {
    let scheme = url.scheme?.lowercased()
    let host = url.host?.lowercased()
    let path = url.path
    let expectedHost = URL(string: InviteConstants.baseURL)?.host?.lowercased()
    let isWeb = scheme == "https" && host == expectedHost && path.hasPrefix("/join/")
    let isAppScheme = scheme == InviteConstants.urlScheme && host == "join"
    guard isWeb || isAppScheme else { return nil }
    let code = url.lastPathComponent.trimmingCharacters(in: .whitespaces)
    guard !code.isEmpty, code.count <= 32,
          code.range(of: "^[a-zA-Z0-9_\\-]+$", options: .regularExpression) != nil else { return nil }
    return (code, nil)
  }
}
