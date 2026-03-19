// BattleView.swift
// 「對戰」分頁：列出目前使用者正在進行中的對戰單字集，並可一鍵進入對戰。

import SwiftUI
import SwiftData

struct BattleView: View {
  @EnvironmentObject private var authService: AuthService
  @EnvironmentObject private var pendingBattleOpenStore: PendingBattleOpenStore
  @Query(sort: \WordSet.createdAt, order: .reverse) private var wordSets: [WordSet]

  @State private var activeBattles: [ActiveBattle] = []
  @State private var isLoading = false
  @State private var errorMessage: String?

  @State private var loadTask: Task<Void, Never>?

  // NavigationStack path for deep-link / row navigation.
  @State private var navPath: [BattleNavItem] = []
  @State private var lastDeepLinkHandled: UUID?

  var body: some View {
    NavigationStack(path: $navPath) {
      ScrollView {
        VStack(spacing: 20) {
          CompactPageHeader("對戰")

          VStack(alignment: .leading, spacing: 12) {
            Text("你的進行中對戰會在這裡整理，點一下即可進入對戰房間。")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 2)
          }

          if isLoading {
            VStack(spacing: 12) {
              ProgressView()
                .scaleEffect(0.9)
              Text("載入進行中的對戰…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
          } else if let errorMessage, !errorMessage.isEmpty {
            ContentUnavailableView(
              "無法載入對戰",
              systemImage: "exclamationmark.triangle",
              description: Text(errorMessage)
            )
            .padding(.top, 8)
          } else if activeBattles.isEmpty {
            ContentUnavailableView(
              "目前沒有進行中的對戰",
              systemImage: "trophy",
              description: Text("你可以到「單字集」發起對戰；發起後，這裡會自動顯示正在進行的對戰。")
            )
            .padding(.top, 8)
          } else {
            VStack(spacing: 12) {
              ForEach(activeBattles) { item in
                battleRow(item)
              }
            }
          }
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 32)
      }
      .refreshable {
        await loadActiveBattles()
      }
      .background(Color(.systemGroupedBackground))
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: BattleNavItem.self) { item in
        switch item {
        case .room(let roomNav):
          BattleRoomView(
            roomId: roomNav.roomId,
            wordSetID: roomNav.wordSetID,
            wordSetTitle: roomNav.wordSetTitle,
            startDate: roomNav.startDate,
            durationDays: roomNav.durationDays,
            invitedMemberIDs: roomNav.invitedMemberIDs,
            creatorId: roomNav.creatorId
          )
        case .initiation(let wordSetID, let wordSetTitle):
          BattleInitiationView(wordSetID: wordSetID, wordSetTitle: wordSetTitle)
        }
      }
      .onAppear {
        // 若 deep link 已經在進入 tab 前被設定，這裡要負責「初始」導航。
        if pendingBattleOpenStore.openKind == .battle,
           let pendingId = pendingBattleOpenStore.wordSetIdToOpen,
           lastDeepLinkHandled != pendingId {
          lastDeepLinkHandled = pendingId
          loadTask?.cancel()
          loadTask = Task {
            await handleDeepLink(wordSetID: pendingId)
          }
        } else {
          startLoading()
        }
      }
      .onDisappear {
        loadTask?.cancel()
      }
      .onChange(of: pendingBattleOpenStore.wordSetIdToOpen) { _, newValue in
        guard pendingBattleOpenStore.openKind == .battle else { return }
        guard let newValue else { return }
        guard lastDeepLinkHandled != newValue else { return }
        lastDeepLinkHandled = newValue
        loadTask?.cancel()
        loadTask = Task {
          await handleDeepLink(wordSetID: newValue)
        }
      }
    }
  }

  private func startLoading() {
    loadTask?.cancel()
    loadTask = Task {
      await loadActiveBattles()
    }
  }

  private func loadActiveBattles() async {
    guard let currentUserId = authService.currentUserId else { return }

    await MainActor.run {
      isLoading = true
      errorMessage = nil
      activeBattles = []
    }

    do {
      // 逐個單字集查是否有進行中對戰；通常「正在對戰」的單字集數量不會很多。
      let service = BattleRoomService(authService: authService, userId: currentUserId)
      var results: [ActiveBattle] = []

      for ws in wordSets {
        if Task.isCancelled { return }
        if let session = try await service.fetchActiveRoom(wordSetID: ws.id) {
          results.append(ActiveBattle(session: session, wordSet: ws))
        }
      }

      results.sort { $0.session.startDate > $1.session.startDate }

      await MainActor.run {
        activeBattles = results
        isLoading = false
      }
    } catch {
      await MainActor.run {
        errorMessage = error.localizedDescription
        isLoading = false
      }
    }
  }

  private func handleDeepLink(wordSetID: UUID) async {
    // 深連結可能會在畫面剛切入時觸發，避免畫面尚未載入字典集資料。
    guard let ws = wordSets.first(where: { $0.id == wordSetID }) else {
      await MainActor.run {
        // 找不到單字集：退回到列表狀態並清除 deep link，避免重複觸發。
        pendingBattleOpenStore.clearWordSetIdToOpen()
      }
      return
    }

    guard let currentUserId = authService.currentUserId else {
      await MainActor.run { pendingBattleOpenStore.clearWordSetIdToOpen() }
      return
    }

    let service = BattleRoomService(authService: authService, userId: currentUserId)
    do {
      if let session = try await service.fetchActiveRoom(wordSetID: wordSetID) {
        let roomNav = BattleRoomNav(
          roomId: session.roomId,
          wordSetID: session.wordSetID,
          wordSetTitle: ws.title,
          startDate: session.startDate,
          durationDays: session.durationDays,
          invitedMemberIDs: session.invitedMemberIDs,
          creatorId: session.creatorId
        )
        await MainActor.run {
          navPath = [.room(roomNav)]
          pendingBattleOpenStore.clearWordSetIdToOpen()
        }
        if !Task.isCancelled {
          await loadActiveBattles()
        }
      } else {
        await MainActor.run {
          navPath = [.initiation(wordSetID: ws.id, wordSetTitle: ws.title)]
          pendingBattleOpenStore.clearWordSetIdToOpen()
        }
        if !Task.isCancelled {
          await loadActiveBattles()
        }
      }
    } catch {
      await MainActor.run {
        errorMessage = error.localizedDescription
        isLoading = false
        pendingBattleOpenStore.clearWordSetIdToOpen()
      }
    }
  }

  private func battleRow(_ item: ActiveBattle) -> some View {
    Button {
      navPath.append(.room(item.roomNav))
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(item.wordSet.title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.primary)
          Spacer()
          Text("進行中")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.90))
            .clipShape(Capsule())
        }

        Text("結束時間：\(formatDate(item.session.endDate))")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)

        HStack(spacing: 8) {
          Image(systemName: "flag.2.crossed.fill")
          Text("進入對戰")
            .font(.system(size: 14, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.purple.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundStyle(.white)
        .padding(.top, 4)
      }
      .padding(16)
      .background(Color(.secondarySystemGroupedBackground))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func formatDate(_ date: Date) -> String {
    Self.dateFormatter.string(from: date)
  }

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()
}

// MARK: - Navigation / Models (UI-only helpers)

private struct ActiveBattle: Identifiable {
  let session: BattleSession
  let wordSet: WordSet

  var id: UUID { session.roomId }

  var roomNav: BattleRoomNav {
    BattleRoomNav(
      roomId: session.roomId,
      wordSetID: session.wordSetID,
      wordSetTitle: wordSet.title,
      startDate: session.startDate,
      durationDays: session.durationDays,
      invitedMemberIDs: session.invitedMemberIDs,
      creatorId: session.creatorId
    )
  }
}

private struct BattleRoomNav: Hashable {
  let roomId: UUID
  let wordSetID: UUID
  let wordSetTitle: String
  let startDate: Date
  let durationDays: Int
  let invitedMemberIDs: [UUID]
  let creatorId: UUID?
}

private enum BattleNavItem: Hashable {
  case room(BattleRoomNav)
  case initiation(wordSetID: UUID, wordSetTitle: String)
}
