// SupabaseConfig.example.swift
// 複製此檔為 SupabaseConfig.swift，填入你的 Supabase Project URL 與 anon key，勿提交 SupabaseConfig.swift
// 取得方式：Supabase Dashboard > Project Settings > API

import Foundation

enum SupabaseConfig {
  /// Project URL（例如 https://xxxxx.supabase.co）
  static let url = URL(string: "<YOUR_SUPABASE_URL>")!
  
  /// anon public key（一長串 JWT，請勿使用 service_role key）
  static let anonKey = "<YOUR_SUPABASE_ANON_KEY>"
}
