// EditProfileView.swift
// 編輯用戶個人資料（頭貼和名字）

import SwiftUI
import SwiftData
import PhotosUI

struct EditProfileView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext
  let currentProfile: UserProfile?
  let userId: UUID?
  
  @State private var displayName: String
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var avatarImage: UIImage?
  
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
          // 頭貼選擇
          VStack(spacing: 16) {
            if let avatarImage = avatarImage {
              Image(uiImage: avatarImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            } else if let avatarURL = currentProfile?.avatarURL, avatarURL.hasPrefix("http"), let url = URL(string: avatarURL) {
              AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                  defaultAvatar
                @unknown default:
                  defaultAvatar
                }
              }
              .frame(width: 120, height: 120)
              .clipShape(Circle())
            } else {
              defaultAvatar
            }
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
              Text("選擇頭貼")
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            .onChange(of: selectedPhoto) { _, newItem in
              Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                  avatarImage = image
                  // 圖片會儲存為 Data 到資料庫，不需要檔案路徑
                }
              }
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
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
            saveProfile()
            dismiss()
          }
        }
      }
    }
  }
  
  private var defaultAvatar: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: [.blue, .purple],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .frame(width: 120, height: 120)
      .overlay {
        Image(systemName: "person.fill")
          .font(.system(size: 60))
          .foregroundStyle(.white)
      }
  }
  
  private func saveProfile() {
    guard let userId = userId else { return }
    
    // 將選擇的圖片轉換為 Data
    let avatarData = avatarImage?.jpegData(compressionQuality: 0.8)
    
    if let profile = currentProfile {
      // 更新現有資料
      profile.displayName = displayName
      if let avatarData = avatarData {
        profile.avatarData = avatarData
        // 清除遠端 URL（因為現在使用本地資料）
        profile.avatarURL = nil
      }
      profile.updatedAt = Date()
    } else {
      // 創建新資料
      let profile = UserProfile(
        userId: userId,
        displayName: displayName,
        avatarData: avatarData,
        avatarURL: nil
      )
      modelContext.insert(profile)
    }
    
    try? modelContext.save()
  }
}
