// AddWordSetView.swift
// View for creating a new word set

import SwiftUI
import SwiftData
import WidgetKit
import PhotosUI
import UIKit

struct AddWordSetView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) var dismiss

  @State private var title = ""
  @State private var selectedLevel: String? = nil

  // ✅ icon settings
  @State private var iconType: WordSetIconType = .emoji
  @State private var selectedEmoji: String = "📘"
  @State private var customEmoji: String = ""
  @State private var photoItem: PhotosPickerItem? = nil
  @State private var pickedImageData: Data? = nil

  let levels = ["初級", "中級", "高級"]

  private let presetEmojis: [String] = [
    "📘","📗","📙","📕","🧠","📝","🔤","🗣️","🌍","✈️","💻","📈","🧪","🎯","🧩","📚"
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("基本資訊")) {
          TextField("標題（例如：韓文第六課）", text: $title)

          Picker("等級", selection: $selectedLevel) {
            Text("無").tag(nil as String?)
            ForEach(levels, id: \.self) { level in
              Text(level).tag(level as String?)
            }
          }
        }

        // ✅ 新增：圖示設定
        Section(header: Text("圖示")) {
          Picker("圖示類型", selection: $iconType) {
            ForEach(WordSetIconType.allCases) { t in
              Text(t.displayName).tag(t)
            }
          }
          .pickerStyle(.segmented)

          if iconType == .emoji {
            emojiPicker
          } else {
            imagePicker
          }

          HStack(spacing: 12) {
            Text("預覽")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()

            // Preview icon like your list icon block
            WordSetIconPreview(type: iconType, emoji: finalEmoji, imageData: pickedImageData)
          }
          .padding(.top, 4)
        }
      }
      .navigationTitle("新增單字集")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("儲存") {
            let newWordSet = WordSet(title: title, level: selectedLevel)
            newWordSet.iconType = iconType
            newWordSet.iconEmoji = finalEmoji
            newWordSet.iconImageData = pickedImageData

            modelContext.insert(newWordSet)

            do {
              try modelContext.save()
              WidgetReloader.reloadAll()
              dismiss()
            } catch {
              print("❌ Failed to save word set: \(error.localizedDescription)")
            }
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  private var finalEmoji: String {
    let c = customEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
    return c.isEmpty ? selectedEmoji : c
  }

  // MARK: - Emoji UI

  private var emojiPicker: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("選擇預設 Emoji")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
        ForEach(presetEmojis, id: \.self) { e in
          Button {
            selectedEmoji = e
            // 不清空 customEmoji，讓使用者可自由切換
          } label: {
            ZStack {
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(selectedEmoji == e ? 0.18 : 0.10))
              Text(e)
                .font(.system(size: 20))
            }
            .frame(height: 38)
          }
          .buttonStyle(.plain)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("自訂 Emoji（可留空）")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("例如：🔥 / 🍀 / 🐳", text: $customEmoji)
          .textInputAutocapitalization(.never)
      }
    }
    .onAppear {
      // 切回 emoji 時不動圖片資料，方便使用者再切回
    }
  }

  // MARK: - Image UI

  private var imagePicker: some View {
    VStack(alignment: .leading, spacing: 12) {
      PhotosPicker(selection: $photoItem, matching: .images) {
        HStack(spacing: 10) {
          Image(systemName: "photo.on.rectangle.angled")
          Text(pickedImageData == nil ? "上傳圖片" : "更換圖片")
          Spacer()
        }
      }
      .onChange(of: photoItem) {
        Task { await loadPickedImage() }
      }

      if let data = pickedImageData, let uiImage = UIImage(data: data) {
        HStack(spacing: 12) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

          VStack(alignment: .leading, spacing: 6) {
            Text("已選擇圖片")
              .font(.subheadline.weight(.semibold))
            Text("建議使用正方形或接近正方形圖片")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button(role: .destructive) {
            pickedImageData = nil
            photoItem = nil
          } label: {
            Image(systemName: "trash")
          }
          .buttonStyle(.borderless)
        }
      } else {
        Text("尚未選擇圖片")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  @MainActor
  private func loadPickedImage() async {
    guard let item = photoItem else { return }
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: data) else { return }

      // 壓縮成小圖，避免 SwiftData 資料庫暴增
      let resized = uiImage.kb_resized(maxSide: 256) ?? uiImage
      let jpeg = resized.jpegData(compressionQuality: 0.82)

      pickedImageData = jpeg ?? data
    } catch {
      print("❌ loadPickedImage error: \(error.localizedDescription)")
    }
  }
}

// MARK: - Preview Icon (small, local)

private struct WordSetIconPreview: View {
  let type: WordSetIconType
  let emoji: String
  let imageData: Data?

  var body: some View {
    WordSetIconView(wordSet: makeTempWordSet(), size: 46, cornerRadius: 16)
  }

  private func makeTempWordSet() -> WordSet {
    let ws = WordSet(title: "temp")
    ws.iconType = type
    ws.iconEmoji = emoji
    ws.iconImageData = imageData
    return ws
  }
}

// MARK: - UIImage resize helper

private extension UIImage {
  func kb_resized(maxSide: CGFloat) -> UIImage? {
    let w = size.width, h = size.height
    guard max(w, h) > maxSide else { return self }

    let scale = maxSide / max(w, h)
    let newSize = CGSize(width: w * scale, height: h * scale)

    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    draw(in: CGRect(origin: .zero, size: newSize))
    let img = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return img
  }
}
