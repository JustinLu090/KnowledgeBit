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
  
  /// 同步 profile 至遠端。若有本地 UserProfile（使用者曾編輯），優先使用；否則用 Google/Auth 資料
  func refreshUserProfile(authService: AuthService, localProfile: UserProfile?) async {
    guard authService.currentUserId != nil else { return }
    isRefreshing = true
    errorMessage = nil
    defer { isRefreshing = false }

    let displayName: String
    let avatarURL: String?

    if let profile = localProfile {
      // 使用者曾編輯：以本地為準，同步至遠端
      displayName = profile.displayName.isEmpty ? "使用者" : profile.displayName
      avatarURL = profile.avatarURL
    } else {
      // 無本地編輯：從 Google / Auth 取得
      let googleUser = GIDSignIn.sharedInstance.currentUser
      let nameFromGoogle = googleUser?.profile?.name
      let avatarURLFromGoogle = googleUser?.profile?.imageURL(withDimension: 200)?.absoluteString
      let (metadataName, metadataAvatar) = authService.metadataDisplayNameAndAvatar()
      displayName = (nameFromGoogle ?? metadataName ?? authService.currentUserDisplayName) ?? "使用者"
      avatarURL = avatarURLFromGoogle ?? metadataAvatar ?? authService.currentUserAvatarURL
    }

    let finalName = displayName.isEmpty ? "使用者" : displayName
    await authService.syncProfileToRemote(displayName: finalName, avatarURL: avatarURL)
  }
}
