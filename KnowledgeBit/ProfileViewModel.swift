// ProfileViewModel.swift
// 個人頁面 ViewModel：從 Google 取得最新 profile 並同步至遠端

import Foundation
import SwiftUI
import Combine
import GoogleSignIn

@MainActor
final class ProfileViewModel: ObservableObject {
  @Published private(set) var isRefreshing = false
  @Published var errorMessage: String?
  
  init() {}
  
  /// 從 Google Sign-In SDK 取得當前用戶 profile，並將 name、picture URL 透過 API 更新至遠端資料庫與 App Group
  func refreshUserProfile(authService: AuthService) async {
    guard authService.currentUserId != nil else { return }
    isRefreshing = true
    errorMessage = nil
    defer { isRefreshing = false }
    
    // 1. 優先從 Google Sign-In SDK 取得當前用戶的 profile（反映 Google 帳號最新狀態）
    let googleUser = GIDSignIn.sharedInstance.currentUser
    let nameFromGoogle = googleUser?.profile?.name
    let avatarURLFromGoogle = googleUser?.profile?.imageURL(withDimension: 200)?.absoluteString
    
    // 2. 若 SDK 無資料（例如僅從 session 還原），則用 Auth session 的 userMetadata
    let (metadataName, metadataAvatar) = authService.metadataDisplayNameAndAvatar()
    let displayName = (nameFromGoogle ?? metadataName ?? authService.currentUserDisplayName) ?? "使用者"
    let finalName = displayName.isEmpty ? "使用者" : displayName
    let avatarURL = avatarURLFromGoogle ?? metadataAvatar ?? authService.currentUserAvatarURL
    
    // 3. 透過 API 更新至遠端資料庫（Supabase user_profiles）並寫入 App Group
    await authService.syncProfileToRemote(displayName: finalName, avatarURL: avatarURL)
  }
}
