// 範本：複製此檔為 SupabaseSecrets.swift，並填入 Supabase Dashboard > Project Settings > API 的真實值。
// SupabaseSecrets.swift 已列入 .gitignore，請勿提交含真實憑證的版本至版控。

import Foundation

/// 本機 Supabase 憑證（請勿提交含真實 key 的檔案至版控）。
enum SupabaseSecrets {
  /// Project URL（例如 https://YOUR_PROJECT_REF.supabase.co）
  static let projectURL: URL = URL(string: "https://YOUR_PROJECT_REF.supabase.co")!

  /// Publishable key（新版，格式為 sb_publishable_...，僅用於 client，勿使用 secret key）
  static let publishableKey: String = "YOUR_PUBLISHABLE_KEY"
}
