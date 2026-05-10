// CollaboratorPickerView.swift
// 邀請好友共編單字集的 sheet。從 WordSetDetailView 推開。
// 包含：好友清單、已加入/邀請中狀態標記、發送邀請、失敗訊息提示。

import SwiftUI
import os

struct CollaboratorPickerView: View {
  @Environment(\.dismiss) private var dismiss
  let authService: AuthService
  let wordSetId: UUID
  let initialSelectedIds: Set<UUID>
  let onUpdated: ([WordSetCollaborator]) -> Void

  @StateObject private var communityViewModel = CommunityViewModel()
  @State private var localSelection: Set<UUID> = []
  /// 已邀請過我的使用者 ID（pending）；顯示為「已加入」且不可再邀請。
  @State private var pendingInviterIds: Set<UUID> = []
  /// 我已發出邀請、對方尚未接受/拒絕的使用者 ID；顯示「邀請中」。
  @State private var pendingInviteeIds: Set<UUID> = []
  /// 發送邀請後若有失敗，顯示錯誤訊息。
  @State private var sendInvitationErrorMessage: String?
  /// 最後一筆發送失敗的後端訊息（用於補充 hint）。
  @State private var lastSendInvitationError: String?

  var body: some View {
    NavigationStack {
      List {
        if communityViewModel.isLoading {
          HStack {
            ProgressView()
            Text("載入好友中…")
              .foregroundStyle(.secondary)
          }
        } else if let error = communityViewModel.errorMessage {
          VStack(alignment: .leading, spacing: 8) {
            Text("載入失敗")
              .font(.headline)
            Text(error)
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Button("重試") {
              Task { await communityViewModel.loadFriends(authService: authService) }
            }
            .buttonStyle(.bordered)
          }
        } else if communityViewModel.friends.isEmpty {
          Text("目前尚無好友可邀請。")
            .foregroundStyle(.secondary)
        } else {
          Section {
            Text("選擇要邀請的好友，對方會在「社群」收到邀請並可選擇接受或拒絕。")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Section("好友") {
            ForEach(communityViewModel.friends) { friend in
              friendRow(friend: friend)
            }
          }
        }
      }
      .navigationTitle("邀請共編成員")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("邀請") {
            Task { await sendInvitations() }
          }
          .disabled(localSelection.isEmpty)
        }
      }
      .task {
        await communityViewModel.loadFriends(authService: authService)
        localSelection = initialSelectedIds
        if let currentUserId = authService.currentUserId {
          let invitationService = WordSetInvitationService(authService: authService, userId: currentUserId)
          let myPending = (try? await invitationService.fetchMyPendingInvitations()) ?? []
          pendingInviterIds = Set(myPending.filter { $0.wordSetId == wordSetId }.map(\.inviterId))
          let mySentPending = (try? await invitationService.fetchPendingInvitations(wordSetId: wordSetId)) ?? []
          pendingInviteeIds = Set(mySentPending.map(\.inviteeId))
        }
      }
      .alert("發送邀請失敗", isPresented: Binding(
        get: { sendInvitationErrorMessage != nil },
        set: { if !$0 { sendInvitationErrorMessage = nil } }
      )) {
        Button("確定", role: .cancel) { sendInvitationErrorMessage = nil }
      } message: {
        if let msg = sendInvitationErrorMessage {
          Text(msg)
        }
      }
    }
  }

  // MARK: - Friend Row

  @ViewBuilder
  private func friendRow(friend: FriendItem) -> some View {
    let isAlreadyCollaborator = initialSelectedIds.contains(friend.userId) || pendingInviterIds.contains(friend.userId)
    let isPendingInvitee = pendingInviteeIds.contains(friend.userId)
    let cannotSelect = isAlreadyCollaborator || isPendingInvitee
    Button {
      if !cannotSelect { toggleSelection(friend.userId) }
    } label: {
      HStack(spacing: 12) {
        CollaboratorAvatarView(displayName: friend.displayName, avatarURL: friend.avatarURL, size: 44)
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(friend.displayName)
              .font(.body)
            if isAlreadyCollaborator {
              statusBadge(text: "已加入", color: .green)
            } else if isPendingInvitee {
              statusBadge(text: "邀請中", color: .orange)
            }
          }
          Text("Lv \(friend.level)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        selectionIndicator(
          isAlreadyCollaborator: isAlreadyCollaborator,
          isPendingInvitee: isPendingInvitee,
          isSelected: localSelection.contains(friend.userId)
        )
      }
    }
    .buttonStyle(.plain)
    .disabled(cannotSelect)
  }

  private func statusBadge(text: String, color: Color) -> some View {
    Text(text)
      .font(.caption2)
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color)
      .cornerRadius(6)
  }

  @ViewBuilder
  private func selectionIndicator(isAlreadyCollaborator: Bool, isPendingInvitee: Bool, isSelected: Bool) -> some View {
    if isAlreadyCollaborator {
      Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
    } else if isPendingInvitee {
      Image(systemName: "clock.fill").font(.caption).foregroundStyle(.orange)
    } else if isSelected {
      Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
    } else {
      Image(systemName: "circle").foregroundStyle(.tertiary)
    }
  }

  // MARK: - Actions

  private func toggleSelection(_ id: UUID) {
    if localSelection.contains(id) {
      localSelection.remove(id)
    } else {
      localSelection.insert(id)
    }
  }

  /// 發送邀請給選取的好友（對方需在社群接受後才會加入共編）
  private func sendInvitations() async {
    guard let currentUserId = authService.currentUserId else {
      AppLog.wordset.info("⚠️ [WordSet] sendInvitations 跳過：無 currentUserId")
      return
    }
    let invitationService = WordSetInvitationService(authService: authService, userId: currentUserId)
    // 不重複邀請已是共編者、已邀請過我的人、或已發出邀請尚待回覆的人
    let toInvite = localSelection.filter {
      !initialSelectedIds.contains($0) && !pendingInviterIds.contains($0) && !pendingInviteeIds.contains($0)
    }
    AppLog.wordset.info("[WordSet] 邀請共編：wordSetId=\(wordSetId), 將發送給 \(toInvite.count) 人, targetUserIds=\(toInvite.map(\.uuidString))")
    var successCount = 0
    var failureCount = 0
    var succeededIds: [UUID] = []
    for inviteeId in toInvite {
      do {
        try await invitationService.sendInvitation(wordSetId: wordSetId, inviteeId: inviteeId)
        successCount += 1
        succeededIds.append(inviteeId)
        AppLog.wordset.info("✅ [WordSet] sendInvitation Success: inviteeId=\(inviteeId)")
      } catch {
        failureCount += 1
        let errMsg = String(describing: error)
        AppLog.wordset.info("❌ [WordSet] sendInvitation Error: inviteeId=\(inviteeId), error=\(error)")
        lastSendInvitationError = errMsg
      }
    }
    AppLog.wordset.info("[WordSet] 邀請結果：Success=\(successCount), Error=\(failureCount)")

    // 發送成功的人加入「邀請中」，並從選取中移除
    for id in succeededIds {
      pendingInviteeIds.insert(id)
      localSelection.remove(id)
    }
    if failureCount > 0 {
      let hint = (lastSendInvitationError?.contains("word_set not found") == true)
        ? "（此單字集尚未同步至伺服器，請確認網路連線後重試。）"
        : ""
      sendInvitationErrorMessage = "有 \(failureCount) 筆邀請發送失敗，請稍後再試。\(hint)"
    } else {
      dismiss()
    }
  }
}
