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
      
      // 等待 session 更新，並讓 Supabase 有時間寫入 user_metadata（full_name, picture）
      for _ in 0..<3 {
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 秒
        if auth.currentUserId != nil { break }
      }
      
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
  
  /// 儲存 Google 用戶資訊到 UserProfile（本地 SwiftData + Supabase user_profiles）
  private func saveGoogleUserProfile(userId: UUID, googleUser: GIDGoogleUser) async {
    // 從 Auth userMetadata 擷取備用（Supabase 會從 Google token 寫入 full_name / picture）
    let (metadataName, metadataAvatar) = auth.metadataDisplayNameAndAvatar()
    
    // 名字：優先 Google profile.name，其次 session userMetadata（full_name / name），最後 email 前綴
    let displayName = (googleUser.profile?.name ?? metadataName ?? auth.currentUserDisplayName) ?? "使用者"
    let finalDisplayName = displayName.isEmpty ? "使用者" : displayName
    
    // 頭像 URL：優先 Google profile，其次 session userMetadata（picture / avatar_url）
    let avatarURLFromGoogle = googleUser.profile?.imageURL(withDimension: 200)?.absoluteString
    let avatarURLForSync = avatarURLFromGoogle ?? metadataAvatar ?? auth.currentUserAvatarURL
    
    // 下載 Google 頭貼並轉換為 Data（供本地顯示）
    var avatarData: Data? = nil
    if let urlString = avatarURLForSync ?? avatarURLFromGoogle, let url = URL(string: urlString) {
      do {
        let (data, _) = try await URLSession.shared.data(from: url)
        avatarData = data
      } catch {
        print("⚠️ 無法下載 Google 頭貼: \(error)")
      }
    }
    
    let descriptor = FetchDescriptor<UserProfile>(
      predicate: #Predicate<UserProfile> { $0.userId == userId }
    )
    
    if let existingProfile = try? modelContext.fetch(descriptor).first {
      if existingProfile.displayName == "使用者" || existingProfile.avatarData == nil {
        existingProfile.displayName = finalDisplayName
        if let avatarData = avatarData {
          existingProfile.avatarData = avatarData
          existingProfile.avatarURL = nil
        } else {
          existingProfile.avatarURL = avatarURLForSync
        }
        existingProfile.updatedAt = Date()
      }
    } else {
      let profile = UserProfile(
        userId: userId,
        displayName: finalDisplayName,
        avatarData: avatarData,
        avatarURL: avatarData == nil ? avatarURLForSync : nil
      )
      modelContext.insert(profile)
    }
    
    try? modelContext.save()
    
    // 必定將 display_name、avatar_url 寫入 Supabase user_profiles（含 Auth metadata 備用）
    await syncProfileToSupabase(userId: userId, displayName: finalDisplayName, avatarURL: avatarURLForSync)
    
    // 同步至 App Group UserDefaults（供 Widget 與主 App 一致）
    auth.saveProfileToAppGroup(displayName: finalDisplayName, avatarURL: avatarURLForSync)
  }
  
  /// 將 display_name、avatar_url 寫入 Supabase user_profiles（依 user_id 更新或插入，避免 duplicate key）
  private func syncProfileToSupabase(userId: UUID, displayName: String, avatarURL: String?) async {
    let client = auth.getClient()
    struct ProfileUpdate: Encodable {
      let display_name: String
      let avatar_url: String?
      let updated_at: Date
    }
    struct ProfileInsert: Encodable {
      let user_id: UUID
      let display_name: String
      let avatar_url: String?
      let updated_at: Date
    }
    do {
      let insertPayload = ProfileInsert(user_id: userId, display_name: displayName, avatar_url: avatarURL, updated_at: Date())
      do {
        try await client.from("user_profiles").insert(insertPayload).execute()
      } catch {
        let updatePayload = ProfileUpdate(display_name: displayName, avatar_url: avatarURL, updated_at: Date())
        try await client
          .from("user_profiles")
          .update(updatePayload)
          .eq("user_id", value: userId)
          .execute()
      }
      print("✅ [Login] 已同步 display_name、avatar_url 至 Supabase user_profiles")
    } catch {
      print("⚠️ [Login] Supabase user_profiles 同步失敗: \(error.localizedDescription)")
    }
  }
}

#Preview {
  LoginView()
    .environmentObject(AuthService())
}
