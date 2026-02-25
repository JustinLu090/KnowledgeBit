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
              // 簡化頭像顯示（此專案已有 AvatarView，但為避免相依，這裡使用系統圖示）
              Image(systemName: "person.crop.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
              VStack(alignment: .leading, spacing: 2) {
                Text(m.displayName)
                  .font(.body)
                Text(m.id.uuidString.prefix(8) + "…")
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              }
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
          navigateToBattle = true
        } label: {
          Text("開始戰鬥")
            .fontWeight(.bold)
        }
        .disabled(isLoading || invited.isEmpty)
      }
    }
    .background(
      NavigationLink(
        destination: StrategicBattleView(wordSetID: wordSetID, wordSetTitle: wordSetTitle),
        isActive: $navigateToBattle,
        label: { EmptyView() }
      )
      .hidden()
    )
    .onAppear { loadCollaborators() }
  }

  // 載入共編成員（占位實作）
  private func loadCollaborators() {
    isLoading = true
    errorMessage = nil
    members = []
    invited = []

    // TODO: 之後可整合實際的共編 API；這裡先用簡單的 mock，確保畫面流程可用
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      // 若未登入，顯示空列表即可
      guard authService.isLoggedIn else {
        isLoading = false
        return
      }
      // 模擬 3 位共編成員（不含自己）
      let mock: [Member] = [
        Member(id: UUID(), displayName: "Alice", avatarURL: nil),
        Member(id: UUID(), displayName: "Bob", avatarURL: nil),
        Member(id: UUID(), displayName: "Charlie", avatarURL: nil)
      ]
      members = mock
      isLoading = false
    }
  }
}

#Preview {
  NavigationStack {
    BattleInitiationView(wordSetID: UUID(), wordSetTitle: "韓文第六課")
      .environmentObject(AuthService())
  }
}
