// SupabaseConfig.swift
// 請到 Supabase Dashboard > Project Settings > API 複製並替換下面兩個值

import Foundation

enum SupabaseConfig {
  /// Project URL（例如 https://xxxxx.supabase.co）
  static let url = URL(string: "https://ktjuguupudpvavlcogvj.supabase.co")!

  /// anon public key（一長串 JWT）
  static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt0anVndXVwdWRwdmF2bGNvZ3ZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzMjI3ODYsImV4cCI6MjA4NTg5ODc4Nn0.IBhw9Jkrmro_VjUErK8_SrEBTpJ9jjWwH9Onxd7m19A"
}
