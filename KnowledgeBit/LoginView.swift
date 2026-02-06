// LoginView.swift
// 登入畫面，未登入時顯示（僅 Google 登入）

import SwiftUI
import SwiftData
import Supabase
import Auth
import GoogleSignIn

struct LoginView: View {
  @EnvironmentObject var auth: AuthService
  @Environment(\.modelContext) private var modelContext
  @State private var errorMessage: String?
  @State private var isLoading = false
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 32) {
        Spacer()
        
        // Logo / 標題
        VStack(spacing: 16) {
          Image(systemName: "book.closed.fill")
            .font(.system(size: 64))
            .foregroundStyle(.blue)
          Text("KnowledgeBit")
            .font(.largeTitle.bold())
        }
        
        Spacer()
        
        // Google 登入按鈕
        VStack(spacing: 16) {
          Button {
            Task {
              await handleGoogleSignIn()
            }
          } label: {
            HStack(spacing: 12) {
              if isLoading {
                ProgressView()
                  .tint(.blue)
              } else {
                Image(systemName: "globe")
                  .font(.system(size: 18))
              }
              Text("使用 Google 帳號登入")
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(.systemBackground))
            .foregroundStyle(.blue)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .cornerRadius(12)
          }
          .disabled(isLoading)
          
          if let msg = errorMessage ?? auth.errorMessage {
            Text(msg)
              .font(.caption)
              .foregroundStyle(.red)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
        }
        .padding(.horizontal, 24)
        
        Spacer()
      }
      .background(Color(.systemGroupedBackground))
      .navigationBarTitleDisplayMode(.inline)
    }
  }
  
  /// 處理 Google 登入流程
  private func handleGoogleSignIn() async {
    errorMessage = nil
    isLoading = true
    defer { isLoading = false }
    
    do {
      // 取得當前視窗場景和 root view controller
      let scenes = UIApplication.shared.connectedScenes
      let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
      
      guard let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first,
            let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? 
            windowScene.windows.first?.rootViewController else {
        errorMessage = "無法取得視窗場景，請稍後再試"
        return
      }
      
      // 從 Info.plist 讀取 REVERSED_CLIENT_ID
      guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: path),
            let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]] else {
        errorMessage = "無法讀取 Info.plist，請確認已在 Xcode 的 URL Types 中設定 REVERSED_CLIENT_ID"
        return
      }
      
      // 尋找包含 REVERSED_CLIENT_ID 的 URL scheme
      var clientIdPrefix: String?
      for urlType in urlTypes {
        if let urlSchemes = urlType["CFBundleURLSchemes"] as? [String] {
          for scheme in urlSchemes {
            if scheme.hasPrefix("com.googleusercontent.apps.") {
              let prefix = scheme.replacingOccurrences(of: "com.googleusercontent.apps.", with: "")
              clientIdPrefix = prefix
              break
            }
          }
        }
        if clientIdPrefix != nil { break }
      }
      
      guard let prefix = clientIdPrefix else {
        errorMessage = "無法找到 REVERSED_CLIENT_ID，請確認已在 Xcode 的 URL Types 中設定"
        return
      }
      
      // 組合完整的 Client ID
      let clientID = "\(prefix).apps.googleusercontent.com"
      
      // 設定 Google Sign-In 配置
      let config = GIDConfiguration(clientID: clientID)
      GIDSignIn.sharedInstance.configuration = config
      
      // 使用 GIDSignIn.sharedInstance.signIn 取得 idToken 和 accessToken
      // 注意：使用 iOS Client ID (275005599081-ujeurl6h4jhjvmss6uh8pm1b379sa9k9)
      let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
      
      // 取得 idToken 和 accessToken
      guard let idToken = result.user.idToken?.tokenString else {
        errorMessage = "無法取得 Google ID Token"
        return
      }
      
      // 取得 accessToken（用於 Supabase 驗證）
      let accessToken = result.user.accessToken.tokenString
      
      // 呼叫 supabase.auth.signInWithIdToken 與 Supabase 連動
      // 同時傳遞 accessToken 以解決 audience 不匹配問題
      try await auth.signInWithIdToken(provider: .google, idToken: idToken, accessToken: accessToken)
      
      // 等待 session 更新
      try? await Task.sleep(nanoseconds: 500_000_000) // 等待 0.5 秒
      
      // 儲存 Google 用戶資訊到 UserProfile
      if let userId = auth.currentUserId {
        await saveGoogleUserProfile(
          userId: userId,
          googleUser: result.user
        )
      }
      
    } catch {
      errorMessage = error.localizedDescription
      print("❌ Google 登入錯誤: \(error)")
    }
  }
  
  /// 儲存 Google 用戶資訊到 UserProfile
  private func saveGoogleUserProfile(userId: UUID, googleUser: GIDGoogleUser) async {
    // 取得 Google 用戶的名字和頭貼 URL
    let displayName = googleUser.profile?.name ?? "使用者"
    let avatarURL = googleUser.profile?.imageURL(withDimension: 200)?.absoluteString
    
    // 下載 Google 頭貼並轉換為 Data
    var avatarData: Data? = nil
    if let avatarURLString = avatarURL, let url = URL(string: avatarURLString) {
      do {
        let (data, _) = try await URLSession.shared.data(from: url)
        avatarData = data
      } catch {
        print("⚠️ 無法下載 Google 頭貼: \(error)")
      }
    }
    
    // 查詢是否已存在該用戶的資料
    let descriptor = FetchDescriptor<UserProfile>(
      predicate: #Predicate<UserProfile> { $0.userId == userId }
    )
    
    if let existingProfile = try? modelContext.fetch(descriptor).first {
      // 更新現有資料（只有在沒有自訂資料時才更新）
      if existingProfile.displayName == "使用者" || existingProfile.avatarData == nil {
        existingProfile.displayName = displayName
        if let avatarData = avatarData {
          existingProfile.avatarData = avatarData
          existingProfile.avatarURL = nil  // 清除 URL，因為已儲存為 Data
        } else {
          existingProfile.avatarURL = avatarURL  // 如果下載失敗，保留 URL
        }
        existingProfile.updatedAt = Date()
      }
    } else {
      // 創建新資料
      let profile = UserProfile(
        userId: userId,
        displayName: displayName,
        avatarData: avatarData,
        avatarURL: avatarData == nil ? avatarURL : nil  // 如果有 Data 就不需要 URL
      )
      modelContext.insert(profile)
    }
    
    // 儲存變更
    try? modelContext.save()
  }
}

#Preview {
  LoginView()
    .environmentObject(AuthService())
}
