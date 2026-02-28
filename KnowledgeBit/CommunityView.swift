// CommunityView.swift
// 社群功能：好友請求、好友列表、搜尋加好友

import SwiftUI
import SwiftData

struct CommunityView: View {
  @EnvironmentObject var authService: AuthService
  @Environment(\.modelContext) private var modelContext
  @ObservedObject var viewModel: CommunityViewModel
  @ObservedObject var pendingInviteStore: PendingInviteStore
  @FocusState private var isSearchFocused: Bool
  @State private var friendToDelete: FriendItem?
  @State private var wordSetInvitations: [WordSetInvitationItem] = []
  @State private var wordSetInvitationsLoading = false
  @State private var respondingInvitationId: UUID?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // 我的邀請連結與 QR Code
          inviteSection
          // 搜尋欄
          searchSection

          // 單字集邀請（待確認）
          if !wordSetInvitations.isEmpty {
            wordSetInvitationsSection
          }

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
      .scrollDismissesKeyboard(.interactively)
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
      .task {
        await viewModel.refresh(authService: authService)
        await loadWordSetInvitations()
      }
      .refreshable {
        await viewModel.refresh(authService: authService)
        await loadWordSetInvitations()
      }
      .alert("加入好友", isPresented: Binding(
        get: { pendingInviteStore.inviteCode != nil },
        set: { if !$0 { pendingInviteStore.clear() } }
      )) {
        Button("取消", role: .cancel) { pendingInviteStore.clear() }
        Button("發送好友請求") {
          if let code = pendingInviteStore.inviteCode {
            Task { await viewModel.sendFriendRequestByInviteCode(code, authService: authService) }
            pendingInviteStore.clear()
          }
        }
      } message: {
        if let name = pendingInviteStore.inviterDisplayName, !name.isEmpty {
          Text("\(name) 邀請你加入 KnowledgeBit，是否要發送好友請求？")
        } else if pendingInviteStore.inviteCode != nil {
          Text("是否要依此邀請碼發送好友請求？")
        }
      }
    }
  }

  // MARK: - 邀請連結與 QR Code

  private var inviteSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("我的邀請連結")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)
      VStack(spacing: 16) {
        if let qr = viewModel.inviteQRImage {
          Image(uiImage: qr)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 200, height: 200)
        }
        if let urlString = viewModel.inviteShareURL {
          Text(urlString)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
          HStack(spacing: 12) {
            Button {
              UIPasteboard.general.string = urlString
            } label: {
              Label("複製連結", systemImage: "doc.on.doc")
                .font(.system(size: 15, weight: .medium))
            }
            .buttonStyle(.bordered)
            if let url = URL(string: urlString) {
              ShareLink(item: url, subject: Text("邀請你加入 KnowledgeBit")) {
                Label("分享", systemImage: "square.and.arrow.up")
                  .font(.system(size: 15, weight: .medium))
              }
              .buttonStyle(.bordered)
            }
          }
        } else if viewModel.isLoading {
          ProgressView()
            .scaleEffect(0.9)
        } else {
          Text("載入邀請碼中…")
            .font(.system(size: 14))
            .foregroundStyle(.tertiary)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(16)
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(12)
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

  // MARK: - 單字集邀請區塊

  private var wordSetInvitationsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("單字集邀請")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.primary)
        Text("\(wordSetInvitations.count)")
          .font(.system(size: 14))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(Color.orange)
          .cornerRadius(10)
      }
      .padding(.horizontal, 4)

      VStack(spacing: 0) {
        ForEach(wordSetInvitations) { inv in
          WordSetInvitationRow(
            invitation: inv,
            isResponding: respondingInvitationId == inv.id,
            onAccept: {
              Task { await acceptWordSetInvitation(inv.id) }
            },
            onDecline: {
              Task { await declineWordSetInvitation(inv.id) }
            }
          )
        }
      }
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(12)
    }
  }

  private func loadWordSetInvitations() async {
    guard let uid = authService.currentUserId else { return }
    wordSetInvitationsLoading = true
    defer { wordSetInvitationsLoading = false }
    do {
      let service = WordSetInvitationService(authService: authService, userId: uid)
      let list = try await service.fetchMyPendingInvitations()
      await MainActor.run { wordSetInvitations = list }
    } catch {
      print("⚠️ [Community] loadWordSetInvitations 失敗: \(error)")
    }
  }

  private func acceptWordSetInvitation(_ id: UUID) async {
    guard let uid = authService.currentUserId else { return }
    respondingInvitationId = id
    do {
      let service = WordSetInvitationService(authService: authService, userId: uid)
      try await service.acceptInvitation(id: id)
      await loadWordSetInvitations()
      // 接受後立刻拉取可見單字集，讓新加入的共編單字集出現在「我的單字集」
      if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
        await sync.pullVisibleWordSetsAndMergeToLocal(modelContext: modelContext)
      }
    } catch {
      print("⚠️ [Community] acceptWordSetInvitation 失敗: \(error)")
    }
    respondingInvitationId = nil
  }

  private func declineWordSetInvitation(_ id: UUID) async {
    guard let uid = authService.currentUserId else { return }
    respondingInvitationId = id
    do {
      let service = WordSetInvitationService(authService: authService, userId: uid)
      try await service.declineInvitation(id: id)
      await loadWordSetInvitations()
    } catch {
      print("⚠️ [Community] declineWordSetInvitation 失敗: \(error)")
    }
    respondingInvitationId = nil
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

private struct WordSetInvitationRow: View {
  let invitation: WordSetInvitationItem
  let isResponding: Bool
  let onAccept: () -> Void
  let onDecline: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: "book.closed.fill")
        .font(.system(size: 28))
        .foregroundStyle(.orange)
      VStack(alignment: .leading, spacing: 2) {
        Text(invitation.wordSetTitle)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.primary)
        Text("\(invitation.inviterDisplayName) 邀請你共編此單字集")
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
        .disabled(isResponding)
        Button(action: onAccept) {
          if isResponding {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text("接受")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.white)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(Color.blue)
              .cornerRadius(8)
          }
        }
        .buttonStyle(.plain)
        .disabled(isResponding)
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
  CommunityView(viewModel: CommunityViewModel(), pendingInviteStore: PendingInviteStore())
    .environmentObject(AuthService())
}
