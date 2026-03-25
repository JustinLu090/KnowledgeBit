// ⚠️ 此檔案為範本（template），不應包含真實憑證。
// 請複製此檔為本地版本並填入真實值，本地版本已由 .gitignore 排除。
//
// 設定方式：
//   1. 複製此檔案內容至 KnowledgeBit/SupabaseConfig.local.swift（已在 .gitignore 中）
//   2. 在 Supabase Dashboard > Project Settings > API 取得真實值並填入
//   3. 務必 rotate anon key 若原始 key 曾意外提交至版控
//
// 注意：請勿將含有真實憑證的檔案提交至版控

import Foundation

enum SupabaseConfig {
  /// Project URL（例如 https://xxxxx.supabase.co）
  static let url = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!

  /// anon public key（一長串 JWT，僅用於前端，勿使用 service_role key）
  static let anonKey = "YOUR_SUPABASE_ANON_KEY"
}
