// CollaboratorViews.swift
// 與單字集共編成員顯示相關的小型 View 組件：
//   * CollaboratorAvatarView — 圓形頭像（有 URL 用 AvatarView，沒有則顯示 initial）
//   * CollaboratorListSheet  — 列出此單字集所有共編者的 sheet

import SwiftUI

struct CollaboratorAvatarView: View {
  let displayName: String
  var avatarURL: String?
  var size: CGFloat = 28

  private var initials: String {
    String(displayName.prefix(1))
  }

  var body: some View {
    Group {
      if let url = avatarURL, !url.isEmpty {
        AvatarView(avatarURL: url, size: size)
          .clipShape(Circle())
      } else {
        ZStack {
          Circle()
            .fill(Color.blue.opacity(0.85))
          Text(initials)
            .font(size > 32 ? .body.bold() : .caption.bold())
            .foregroundStyle(.white)
        }
      }
    }
    .frame(width: size, height: size)
    .overlay(
      Circle()
        .stroke(Color(.systemBackground), lineWidth: 2)
    )
  }
}

struct CollaboratorListSheet: View {
  @Environment(\.dismiss) private var dismiss
  let collaborators: [WordSetCollaborator]

  var body: some View {
    NavigationStack {
      List {
        if collaborators.isEmpty {
          Text("目前尚無共編成員")
            .foregroundStyle(.secondary)
        } else {
          ForEach(collaborators) { c in
            HStack(spacing: 12) {
              CollaboratorAvatarView(displayName: c.displayName, avatarURL: c.avatarURL, size: 44)
              Text(c.displayName)
                .font(.body)
              Spacer()
            }
          }
        }
      }
      .navigationTitle("共編成員")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("關閉") { dismiss() }
        }
      }
    }
  }
}
