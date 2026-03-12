// 複製此檔內容到新檔 SupabaseConfig.swift，並到 Supabase Dashboard > Project Settings > API 填入真實值。
// 請勿將 SupabaseConfig.swift 提交至版控（應已列於 .gitignore）。

import Foundation

enum SupabaseConfig {
  /// Project URL（例如 https://xxxxx.supabase.co）
  static let url = URL(string: "https://ktjuguupudpvavlcogvj.supabase.co")!
  
  /// anon public key（一長串 JWT，僅用於前端，勿使用 service_role key）
  static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt0anVndXVwdWRwdmF2bGNvZ3ZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzMjI3ODYsImV4cCI6MjA4NTg5ODc4Nn0.IBhw9Jkrmro_VjUErK8_SrEBTpJ9jjWwH9Onxd7m19A"
}
