// EditProfileView.swift
// 編輯用戶個人資料（頭貼和名字）

import SwiftUI
import SwiftData
import PhotosUI

struct EditProfileView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var authService: AuthService
  let currentProfile: UserProfile?
  let userId: UUID?

  @State private var displayName: String
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var avatarImage: UIImage?
  @State private var isSaving = false
  
  init(currentProfile: UserProfile?, userId: UUID?) {
    self.currentProfile = currentProfile
    self.userId = userId
    _displayName = State(initialValue: currentProfile?.displayName ?? "使用者")
    // 如果有儲存的圖片資料，載入顯示
    if let avatarData = currentProfile?.avatarData, let image = UIImage(data: avatarData) {
      _avatarImage = State(initialValue: image)
    } else if let avatarURL = currentProfile?.avatarURL, avatarURL.hasPrefix("http") {
      // 如果是遠端 URL，保持原樣（會用 AsyncImage 載入）
      _avatarImage = State(initialValue: nil)
    } else {
      _avatarImage = State(initialValue: nil)
    }
  }
  
  var body: some View {
    NavigationStack {
      Form {
        Section {
          AvatarPickerSection(
            avatarImage: $avatarImage,
            selectedPhoto: $selectedPhoto,
            avatarURL: currentProfile?.avatarURL,
            avatarData: currentProfile?.avatarData,
            size: 120
          )
        }
        
        Section {
          TextField("名字", text: $displayName)
        } header: {
          Text("顯示名稱")
        }
      }
      .navigationTitle("編輯個人資料")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            Task { await saveProfile() }
          }
          .disabled(isSaving)
        }
      }
    }
  }
  
  private func saveProfile() async {
    guard let userId = userId else { return }
    isSaving = true
    defer { isSaving = false }

    let avatarData = avatarImage?.jpegData(compressionQuality: 0.8)
    var avatarURLToSync: String? = currentProfile?.avatarURL

    // 若有新選擇的頭貼，上傳至 Supabase Storage
    if let avatarData = avatarData {
      do {
        avatarURLToSync = try await authService.uploadAvatar(userId: userId, imageData: avatarData)
      } catch {
        print("⚠️ [EditProfile] 頭貼上傳失敗: \(error)，僅同步名稱。請確認已建立 avatars bucket。")
      }
    }

    // 儲存至本地 SwiftData
    if let profile = currentProfile {
      profile.displayName = displayName
      if let avatarData = avatarData {
        profile.avatarData = avatarData
        profile.avatarURL = avatarURLToSync
      }
      profile.updatedAt = Date()
    } else {
      let profile = UserProfile(
        userId: userId,
        displayName: displayName,
        avatarData: avatarData,
        avatarURL: avatarURLToSync
      )
      modelContext.insert(profile)
    }
    try? modelContext.save()

    // 同步至 Supabase user_profiles 與 App Group
    await authService.syncProfileToRemote(displayName: displayName, avatarURL: avatarURLToSync)
    dismiss()
  }
}
