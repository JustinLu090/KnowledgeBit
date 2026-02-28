// BattleInitiationView.swift
// 發起對戰：選擇共編成員，準備好後由發起人開始戰鬥

import SwiftUI

struct BattleInitiationView: View {
  let wordSetID: UUID
  let wordSetTitle: String

  @EnvironmentObject var authService: AuthService

  struct Member: Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let avatarURL: String?
  }

  @State private var members: [Member] = []
  @State private var invited: Set<UUID> = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var navigateToBattle = false
  @State private var createdSession: BattleSession?
  private let sessionStore = BattleSessionStore()
  @State private var selectedDuration: Int = 7

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text("單字集：\(wordSetTitle)")
            .font(.headline)
          Text("選擇要邀請加入本次戰鬥的共編成員。發起人可在準備好後按下『開始戰鬥』。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
      }

      Section(header: Text("可邀請的共編成員")) {
        if isLoading {
          HStack {
            ProgressView()
            Text("載入中…")
              .foregroundStyle(.secondary)
          }
        } else if let err = errorMessage {
          VStack(alignment: .leading, spacing: 8) {
            Text("載入失敗")
              .font(.headline)
            Text(err)
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Button("重試") { loadCollaborators() }
              .buttonStyle(.bordered)
          }
        } else if members.isEmpty {
          Text("目前沒有可邀請的共編成員")
            .foregroundStyle(.secondary)
        } else {
          ForEach(members) { m in
            HStack(spacing: 12) {
              AvatarView(avatarURL: m.avatarURL, size: 44)
                .clipShape(Circle())
              Text(m.displayName)
                .font(.body)
              Spacer()
              Toggle("邀請", isOn: Binding(
                get: { invited.contains(m.id) },
                set: { newValue in
                  if newValue { invited.insert(m.id) } else { invited.remove(m.id) }
                }
              ))
              .labelsHidden()
            }
            .contentShape(Rectangle())
            .onTapGesture {
              if invited.contains(m.id) { invited.remove(m.id) } else { invited.insert(m.id) }
            }
          }
        }
      }

      Section(header: Text("對戰時長")) {
        VStack(alignment: .leading, spacing: 10) {
          Stepper(value: $selectedDuration, in: 1...30) {
            HStack(spacing: 8) {
              Image(systemName: "clock")
                .foregroundColor(.blue)
              Text("持續")
              Text("\(selectedDuration) 天")
                .bold()
                .foregroundColor(.blue)
            }
          }
          Text("至少 1 天，最多 30 天。發起後將固定此場次的對戰期間。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
      }

      if !members.isEmpty {
        Section(header: Text("準備")) {
          Text("已選擇：\(invited.count) 位成員")
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle("發起對戰")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          Task { await startBattle() }
        } label: {
          Text("開始戰鬥")
            .fontWeight(.bold)
        }
        .disabled(isLoading || invited.isEmpty)
      }
    }
    .navigationDestination(isPresented: $navigateToBattle) {
      if let session = createdSession {
        BattleRoomView(
          roomId: session.roomId,
          wordSetID: session.wordSetID,
          wordSetTitle: wordSetTitle,
          startDate: session.startDate,
          durationDays: session.durationDays,
          invitedMemberIDs: session.invitedMemberIDs,
          creatorId: session.creatorId ?? authService.currentUserId
        )
      }
    }
    .onAppear { loadCollaborators() }
  }

  private func startBattle() async {
    guard let userId = authService.currentUserId else {
      errorMessage = "請先登入"
      return
    }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      let service = BattleRoomService(authService: authService, userId: userId)
      let startDate = Date()
      let roomId = try await service.createRoom(
        wordSetID: wordSetID,
        startDate: startDate,
        durationDays: selectedDuration,
        invitedMemberIDs: Array(invited)
      )
      let session = BattleSession(
        roomId: roomId,
        wordSetID: wordSetID,
        startDate: startDate,
        durationDays: selectedDuration,
        invitedMemberIDs: Array(invited),
        creatorId: userId
      )
      sessionStore.save(session)
      createdSession = session
      navigateToBattle = true
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadCollaborators() {
    isLoading = true
    errorMessage = nil
    members = []
    invited = []

    Task {
      guard let currentUserId = authService.currentUserId else {
        await MainActor.run { isLoading = false }
        return
      }
      let service = WordSetCollaboratorService(authService: authService, userId: currentUserId)
      do {
        let collabs = try await service.fetchCollaborators(wordSetId: wordSetID)
        await MainActor.run {
          // 不顯示自己（發起人一定會帶入），只顯示此共編單字集的其他成員
          members = collabs
            .filter { $0.userId != currentUserId }
            .map { Member(id: $0.userId, displayName: $0.displayName, avatarURL: $0.avatarURL) }
          isLoading = false
        }
      } catch {
        await MainActor.run {
          errorMessage = "無法載入共編成員"
          isLoading = false
        }
        print("⚠️ [BattleInitiation] fetchCollaborators 失敗: \(error)")
      }
    }
  }
}

#Preview {
  NavigationStack {
    BattleInitiationView(wordSetID: UUID(), wordSetTitle: "英文")
      .environmentObject(AuthService())
  }
}
