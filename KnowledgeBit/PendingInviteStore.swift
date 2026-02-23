// PendingInviteStore.swift
// 由 Deep Link（邀請連結）帶入的 invite_code，供社群頁顯示「是否加好友」並發送請求

import Foundation
import Combine

@MainActor
final class PendingInviteStore: ObservableObject {
  @Published var inviteCode: String?
  @Published var inviterDisplayName: String?

  func setPending(inviteCode: String, inviterDisplayName: String?) {
    self.inviteCode = inviteCode
    self.inviterDisplayName = inviterDisplayName
  }

  func clear() {
    inviteCode = nil
    inviterDisplayName = nil
  }
}

