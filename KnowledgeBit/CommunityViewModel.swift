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

  /// 待處理請求數量（用於 tab badge）
  var pendingCount: Int { pendingRequests.count }

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

  /// 一次載入好友與待處理請求
  func refresh(authService: AuthService) async {
    await loadFriends(authService: authService)
    await loadPendingRequests(authService: authService)
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
