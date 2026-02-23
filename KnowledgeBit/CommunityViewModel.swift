// CommunityViewModel.swift
// 社群頁面 ViewModel：好友列表、好友請求、搜尋加好友

import Foundation
import SwiftUI
import Combine

@MainActor
final class CommunityViewModel: ObservableObject {
  @Published private(set) var friends: [FriendItem] = []
  @Published private(set) var pendingRequests: [FriendRequestItem] = []
  @Published private(set) var sentRequestReceiverIds: Set<UUID> = []
  @Published private(set) var searchResults: [SearchUserItem] = []
  @Published private(set) var isLoading = false
  @Published var errorMessage: String?
  @Published var searchQuery = ""

  /// 邀請碼與分享（連結 / QR Code）
  @Published private(set) var myInviteCode: String?
  @Published private(set) var inviteQRImage: UIImage?

  /// 待處理請求數量（用於 tab badge）
  var pendingCount: Int { pendingRequests.count }

  /// 分享連結字串（需先載入 myInviteCode）
  var inviteShareURL: String? {
    guard let code = myInviteCode else { return nil }
    return InviteShareHelper.shareURL(inviteCode: code)
  }

  // MARK: - 載入資料

  func loadFriends(authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let service = FriendService(authService: authService)
      friends = try await service.fetchFriends(currentUserId: currentUserId)
    } catch {
      errorMessage = "無法載入好友列表"
      print("⚠️ [Community] fetchFriends 失敗: \(error)")
    }
  }

  func loadPendingRequests(authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let service = FriendService(authService: authService)
      pendingRequests = try await service.fetchPendingRequests(currentUserId: currentUserId)
      sentRequestReceiverIds = try await service.fetchSentRequestReceiverIds(currentUserId: currentUserId)
    } catch {
      errorMessage = "無法載入好友請求"
      print("⚠️ [Community] fetchPendingRequests 失敗: \(error)")
    }
  }

  /// 一次載入好友與待處理請求，並更新邀請碼與 QR
  func refresh(authService: AuthService) async {
    await loadFriends(authService: authService)
    await loadPendingRequests(authService: authService)
    await loadInviteCode(authService: authService)
  }

  /// 載入目前使用者的 invite_code 並產生 QR 圖
  func loadInviteCode(authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    do {
      let service = InviteService(authService: authService)
      let code = try await service.fetchMyInviteCode(currentUserId: currentUserId)
      myInviteCode = code
      if let code = code {
        let qrString = InviteShareHelper.appSchemeURL(inviteCode: code)?.absoluteString ?? InviteShareHelper.shareURL(inviteCode: code)
        inviteQRImage = InviteShareHelper.qrImage(for: qrString, sideLength: 400)
      } else {
        inviteQRImage = nil
      }
    } catch {
      myInviteCode = nil
      inviteQRImage = nil
      print("⚠️ [Community] fetchMyInviteCode 失敗: \(error)")
    }
  }

  /// 依邀請碼查詢對方並發送好友請求
  func sendFriendRequestByInviteCode(_ code: String, authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    errorMessage = nil
    do {
      let inviteService = InviteService(authService: authService)
      guard let profile = try await inviteService.fetchProfileByInviteCode(code) else {
        errorMessage = "找不到該邀請碼對應的使用者"
        return
      }
      guard profile.userId != currentUserId else {
        errorMessage = "無法加自己為好友"
        return
      }
      let friendService = FriendService(authService: authService)
      try await friendService.sendFriendRequest(to: profile.userId, currentUserId: currentUserId)
      sentRequestReceiverIds.insert(profile.userId)
      await loadPendingRequests(authService: authService)
    } catch {
      errorMessage = "發送失敗，請稍後再試"
      print("⚠️ [Community] sendFriendRequestByInviteCode 失敗: \(error)")
    }
  }

  // MARK: - 接受 / 拒絕請求

  func acceptRequest(id: UUID, authService: AuthService) async {
    guard authService.currentUserId != nil else { return }
    errorMessage = nil

    do {
      let service = FriendService(authService: authService)
      try await service.acceptFriendRequest(id: id)
      pendingRequests = pendingRequests.filter { $0.id != id }
      await loadFriends(authService: authService)
    } catch {
      errorMessage = "接受失敗，請稍後再試"
      print("⚠️ [Community] acceptFriendRequest 失敗: \(error)")
    }
  }

  func declineRequest(id: UUID, authService: AuthService) async {
    guard authService.currentUserId != nil else { return }
    errorMessage = nil

    do {
      let service = FriendService(authService: authService)
      try await service.declineFriendRequest(id: id)
      pendingRequests = pendingRequests.filter { $0.id != id }
    } catch {
      errorMessage = "拒絕失敗，請稍後再試"
      print("⚠️ [Community] declineFriendRequest 失敗: \(error)")
    }
  }

  // MARK: - 刪除好友

  func deleteFriend(friendUserId: UUID, authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    guard friendUserId != currentUserId else { return }
    errorMessage = nil

    do {
      let service = FriendService(authService: authService)
      try await service.deleteFriend(friendUserId: friendUserId, currentUserId: currentUserId)
      friends = friends.filter { $0.userId != friendUserId }
    } catch {
      errorMessage = "刪除失敗，請稍後再試"
      print("⚠️ [Community] deleteFriend 失敗: \(error)")
    }
  }

  // MARK: - 發送好友請求

  func sendFriendRequest(to userId: UUID, authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    guard userId != currentUserId else { return }
    guard !sentRequestReceiverIds.contains(userId) else { return }
    errorMessage = nil

    do {
      let service = FriendService(authService: authService)
      try await service.sendFriendRequest(to: userId, currentUserId: currentUserId)
      sentRequestReceiverIds.insert(userId)
    } catch {
      errorMessage = "發送失敗，請稍後再試"
      print("⚠️ [Community] sendFriendRequest 失敗: \(error)")
    }
  }

  /// 清除搜尋
  func clearSearch() {
    searchQuery = ""
    searchResults = []
  }

  // MARK: - 搜尋使用者

  func searchUsers(authService: AuthService) async {
    guard let currentUserId = authService.currentUserId else { return }
    let query = searchQuery.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else {
      searchResults = []
      return
    }

    do {
      let service = FriendService(authService: authService)
      let friendIds = friends.map(\.userId)
      let excludeIds = [currentUserId] + friendIds
      searchResults = try await service.searchUsers(query: query, currentUserId: currentUserId, excludeUserIds: excludeIds)
    } catch {
      searchResults = []
      errorMessage = "搜尋失敗"
      print("⚠️ [Community] searchUsers 失敗: \(error)")
    }
  }
}
