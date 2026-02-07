// AvatarView.swift
// 頭像顯示與編輯區塊（降低巢狀、共用邏輯）

import SwiftUI
import PhotosUI

// MARK: - AvatarView (display only)

/// 依 avatarData / avatarURL / localImage 顯示頭像，無則顯示預設頭像
struct AvatarView: View {
  var avatarData: Data?
  var avatarURL: String?
  var localImage: UIImage?
  var size: CGFloat = 100
  
  var body: some View {
    Group {
      if let image = localImage {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: size, height: size)
          .clipShape(Circle())
      } else if let avatarData = avatarData, let image = UIImage(data: avatarData) {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: size, height: size)
          .clipShape(Circle())
      } else if let urlString = avatarURL, urlString.hasPrefix("http"), let url = URL(string: urlString) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            DefaultAvatarView(size: size)
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: size, height: size)
              .clipShape(Circle())
          case .failure:
            DefaultAvatarView(size: size)
          @unknown default:
            DefaultAvatarView(size: size)
          }
        }
      } else {
        DefaultAvatarView(size: size)
      }
    }
  }
}

// MARK: - AvatarPickerSection (edit form)

/// 編輯個人資料用的頭貼區塊：頭像顯示 + PhotosPicker，綁定 avatarImage 與 selectedPhoto
struct AvatarPickerSection: View {
  @Binding var avatarImage: UIImage?
  @Binding var selectedPhoto: PhotosPickerItem?
  var avatarURL: String?
  var avatarData: Data?
  var size: CGFloat = 120
  
  var body: some View {
    VStack(spacing: 16) {
      AvatarView(
        avatarData: avatarData,
        avatarURL: avatarURL,
        localImage: avatarImage,
        size: size
      )
      
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
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }
}
