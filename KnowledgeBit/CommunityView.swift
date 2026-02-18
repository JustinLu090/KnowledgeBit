// CommunityView.swift
// 社群功能：好友請求、好友列表、搜尋加好友

import SwiftUI

struct CommunityView: View {
  @EnvironmentObject var authService: AuthService
  @ObservedObject var viewModel: CommunityViewModel
  @FocusState private var isSearchFocused: Bool
  @State private var friendToDelete: FriendItem?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // 搜尋欄
          searchSection

          // 好友請求（有 pending 時顯示）
          if !viewModel.pendingRequests.isEmpty {
            pendingRequestsSection
          }

          // 好友列表
          friendsSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 32)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("社群")
      .navigationBarTitleDisplayMode(.large)
      .alert("提示", isPresented: .constant(viewModel.errorMessage != nil)) {
        Button("確定") { viewModel.errorMessage = nil }
      } message: {
        if let msg = viewModel.errorMessage {
          Text(msg)
        }
      }
      .alert("解除好友", isPresented: Binding(
        get: { friendToDelete != nil },
        set: { if !$0 { friendToDelete = nil } }
      )) {
        Button("取消", role: .cancel) { friendToDelete = nil }
        Button("刪除", role: .destructive) {
          if let f = friendToDelete {
            Task { await viewModel.deleteFriend(friendUserId: f.userId, authService: authService) }
            friendToDelete = nil
          }
        }
      } message: {
        if let f = friendToDelete {
          Text("確定要解除與 \(f.displayName) 的好友關係嗎？")
        }
      }
      .onAppear {
        Task { await viewModel.refresh(authService: authService) }
      }
      .refreshable {
        await viewModel.refresh(authService: authService)
      }
    }
  }

  // MARK: - 搜尋區塊

  private var searchSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("加入好友")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)

      HStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("依名稱搜尋使用者", text: $viewModel.searchQuery)
          .textFieldStyle(.plain)
          .autocorrectionDisabled()
          .focused($isSearchFocused)
          .submitLabel(.search)
          .onSubmit {
            Task { await viewModel.searchUsers(authService: authService) }
          }
        if !viewModel.searchQuery.isEmpty {
          Button(action: { viewModel.clearSearch() }) {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
        }
        Button("搜尋") {
          isSearchFocused = false
          Task { await viewModel.searchUsers(authService: authService) }
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue)
        .cornerRadius(8)
      }
      .padding(14)
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(12)

      // 搜尋結果
      if !viewModel.searchResults.isEmpty {
        VStack(spacing: 0) {
          ForEach(viewModel.searchResults) { user in
            SearchResultRow(
              user: user,
              isAlreadySent: viewModel.sentRequestReceiverIds.contains(user.userId)
            ) {
              Task { await viewModel.sendFriendRequest(to: user.userId, authService: authService) }
            }
          }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.top, 4)
      }
    }
  }

  // MARK: - 好友請求區塊

  private var pendingRequestsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("好友請求")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.primary)
        Text("\(viewModel.pendingRequests.count)")
          .font(.system(size: 14))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(Color.red)
          .cornerRadius(10)
      }
      .padding(.horizontal, 4)

      VStack(spacing: 0) {
        ForEach(viewModel.pendingRequests) { req in
          PendingRequestRow(request: req) {
            Task { await viewModel.acceptRequest(id: req.id, authService: authService) }
          } onDecline: {
            Task { await viewModel.declineRequest(id: req.id, authService: authService) }
          }
        }
      }
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(12)
    }
  }

  // MARK: - 好友列表區塊

  private var friendsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("好友列表")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)

      if viewModel.friends.isEmpty && !viewModel.isLoading {
        HStack {
          Spacer()
          VStack(spacing: 8) {
            Image(systemName: "person.2.slash")
              .font(.system(size: 40))
              .foregroundStyle(.tertiary)
            Text("尚無好友")
              .font(.system(size: 16))
              .foregroundStyle(.secondary)
            Text("搜尋使用者並發送好友請求")
              .font(.system(size: 14))
              .foregroundStyle(.tertiary)
          }
          .padding(32)
          Spacer()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
      } else {
        VStack(spacing: 0) {
          ForEach(viewModel.friends) { friend in
            FriendRow(friend: friend) {
              friendToDelete = friend
            }
          }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
      }
    }
  }
}

// MARK: - 子視圖

private struct SearchResultRow: View {
  let user: SearchUserItem
  let isAlreadySent: Bool
  let onAdd: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      AvatarView(avatarURL: user.avatarURL, size: 48)
      VStack(alignment: .leading, spacing: 2) {
        Text(user.displayName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.primary)
        Text("Lv.\(user.level)")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }
      Spacer()
      if isAlreadySent {
        Text("已申請")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color(.tertiarySystemFill))
          .cornerRadius(8)
      } else {
        Button(action: onAdd) {
          Text("加好友")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(14)
  }
}

private struct PendingRequestRow: View {
  let request: FriendRequestItem
  let onAccept: () -> Void
  let onDecline: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      AvatarView(avatarURL: request.avatarURL, size: 48)
      VStack(alignment: .leading, spacing: 2) {
        Text(request.displayName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.primary)
        Text("想加你為好友")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 8) {
        Button(action: onDecline) {
          Text("拒絕")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        Button(action: onAccept) {
          Text("確認")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(14)
  }
}

private struct FriendRow: View {
  let friend: FriendItem
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      AvatarView(avatarURL: friend.avatarURL, size: 48)
      VStack(alignment: .leading, spacing: 2) {
        Text(friend.displayName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.primary)
        Text("Lv.\(friend.level)")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(14)
    .contextMenu {
      Button(role: .destructive, action: onDelete) {
        Label("刪除好友", systemImage: "person.badge.minus")
      }
    }
  }
}

#Preview {
  CommunityView(viewModel: CommunityViewModel())
    .environmentObject(AuthService())
}
