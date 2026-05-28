import Foundation

/// App 使用的 Supabase 端點與 publishable key（實際值定義於 `SupabaseSecrets`）。
enum SupabaseConfig {
  static var url: URL { SupabaseSecrets.projectURL }
  static var publishableKey: String { SupabaseSecrets.publishableKey }
}
