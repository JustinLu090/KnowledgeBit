import SwiftUI

/// SwiftData 建立失敗時包裝為 `Error`，供 `Result<ModelContainer, ModelStoreError>` 使用。
struct ModelStoreError: Error, LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

/// SwiftData `ModelContainer` 建立失敗時顯示，取代啟動即 crash。
struct ModelStoreFailureView: View {
  let message: String
  var onRetry: () -> Void

  var body: some View {
    ZStack {
      Color(.systemBackground)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 56))
          .foregroundStyle(.orange)

        Text("無法載入本機資料")
          .font(.title2.bold())

        Text("資料庫初始化失敗。請確認 Xcode 中主 App 與 Widget 的 **App Groups** 與程式內 `AppGroup.identifier` 一致；或刪除 App 後重新安裝以重置資料庫。")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        Text(message)
          .font(.caption)
          .foregroundStyle(.tertiary)
          .multilineTextAlignment(.leading)
          .textSelection(.enabled)
          .padding(.horizontal)

        Button("再試一次") {
          onRetry()
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(32)
    }
  }
}
