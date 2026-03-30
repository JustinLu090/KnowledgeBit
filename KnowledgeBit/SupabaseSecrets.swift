import Foundation

/// 本機 Supabase 憑證（請勿將含真實 key 的檔案提交至公開倉庫；可改為僅本機檔並列入 .gitignore）。
enum SupabaseSecrets {
  static let projectURL: URL = URL(string: "https://ktjuguupudpvavlcogvj.supabase.co")!
  static let anonKey: String =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt0anVndXVwdWRwdmF2bGNvZ3ZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzMjI3ODYsImV4cCI6MjA4NTg5ODc4Nn0.IBhw9Jkrmro_VjUErK8_SrEBTpJ9jjWwH9Onxd7m19A"
}
