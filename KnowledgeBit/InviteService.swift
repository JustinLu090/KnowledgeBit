// InviteService.swift
// 邀請連結與 QR Code：取得 invite_code、組分享 URL、依 invite_code 查詢對方並發送好友請求

import Foundation
import Supabase
import CoreImage
import UIKit

// MARK: - 常數

enum InviteConstants {
  /// 對外分享的 https 邀請連結網域（目前為 Vercel 代理；之後若有自訂網域可改為 https://knowledgebit.io/join）
  static let baseURL = "https://knowledgebit-link-proxy.vercel.app/join"
  /// 自訂 URL Scheme，用於 App 內或未設定 Universal Link 時的跳轉
  static let urlScheme = "knowledgebit"
  static let joinPathPrefix = "/join/"
}

// MARK: - 依 invite_code 查到的公開資料（與 RPC get_profile_by_invite_code 對應）

struct ProfileByInviteCode: Decodable {
  let userId: UUID
  let displayName: String
  let avatarUrl: String?
  let level: Int

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case displayName = "display_name"
    case avatarUrl = "avatar_url"
    case level
  }
}

// MARK: - InviteService

@MainActor
final class InviteService {
  private let client: SupabaseClient

  init(authService: AuthService) {
    client = authService.getClient()
  }

  /// 取得目前使用者的 invite_code（從 user_profiles）
  func fetchMyInviteCode(currentUserId: UUID) async throws -> String? {
    struct Row: Decodable {
      let inviteCode: String?
      enum CodingKeys: String, CodingKey { case inviteCode = "invite_code" }
    }
    let rows: [Row] = try await client
      .from("user_profiles")
      .select("invite_code")
      .eq("user_id", value: currentUserId)
      .limit(1)
      .execute()
      .value
    return rows.first?.inviteCode
  }

  /// 依 invite_code 查詢對方公開資料（呼叫 RPC，僅回傳 user_id, display_name, avatar_url, level）
  func fetchProfileByInviteCode(_ code: String) async throws -> ProfileByInviteCode? {
    let code = code.trimmingCharacters(in: .whitespaces).uppercased()
    guard !code.isEmpty, code.count <= 32 else { return nil }
    let rows: [ProfileByInviteCode] = try await client
      .rpc("get_profile_by_invite_code", params: ["code": code])
      .execute()
      .value
    return rows.first
  }
}

// MARK: - 分享 URL 與 QR Code

enum InviteShareHelper {
  /// 將 invite_code 組合成分享連結
  static func shareURL(inviteCode: String) -> String {
    let code = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()
    return "\(InviteConstants.baseURL)/\(code)"
  }

  /// 自訂 Scheme URL（供 App 內開啟或 fallback）
  static func appSchemeURL(inviteCode: String) -> URL? {
    let code = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()
    guard !code.isEmpty else { return nil }
    return URL(string: "\(InviteConstants.urlScheme)://join/\(code)")
  }

  /// 使用 CoreImage 將字串轉成 QR Code 圖片（高品質、可指定尺寸）
  static func qrImage(for string: String, sideLength: CGFloat = 400) -> UIImage? {
    let data = Data(string.utf8)
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("H", forKey: "inputCorrectionLevel")

    guard let outputImage = filter.outputImage else { return nil }
    let scale = sideLength / outputImage.extent.size.width
    let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let context = CIContext()
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
