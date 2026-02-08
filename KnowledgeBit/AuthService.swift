// AuthService.swift
// 管理 Supabase 登入狀態，供 App 判斷顯示登入畫面或主畫面

import Foundation
import SwiftUI
import Combine
import Supabase
import GoogleSignIn

@MainActor
final class AuthService: ObservableObject {
  /// 目前 session（nil 表示未登入）
  @Published private(set) var session: Session?
  
  /// 登入／註冊錯誤訊息（顯示在畫面上）
  @Published var errorMessage: String?
  
  /// 是否正在執行登入或註冊
  @Published var isLoading = false
  
  private let client: SupabaseClient
  private var authTask: Task<Void, Never>?
  
  // MARK: - App Group UserDefaults（與 Widget 共用；AuthService 為 @MainActor，讀寫皆在主線程，符合 CFPrefs 規範）
  private static let appGroupKeys = (
    displayName: "appgroup_user_display_name",
    avatarURL: "appgroup_user_avatar_url",
    userId: "appgroup_user_id"
  )
  
  private var appGroupDefaults: UserDefaults? {
    AppGroup.sharedUserDefaults()
  }
  
  /// 是否已登入（檢查 session 是否存在且未過期）
  var isLoggedIn: Bool {
    guard let session = session else { return false }
    // 根據最新 SDK 規範，需要檢查 session 是否過期
    return !session.isExpired
  }
  
  /// 當前使用者 ID（RLS 與 API 會用）
  var currentUserId: UUID? {
    session?.user.id
  }
  
  init() {
    // 設定 emitLocalSessionAsInitialSession = true，符合 SDK 建議
    // 使用 SupabaseClientOptions.AuthOptions 的 convenience init（會自動使用 defaultLocalStorage）
    let authOptions = SupabaseClientOptions.AuthOptions(emitLocalSessionAsInitialSession: true)
    let options = SupabaseClientOptions(auth: authOptions)
    
    client = SupabaseClient(
      supabaseURL: SupabaseConfig.url,
      supabaseKey: SupabaseConfig.anonKey,
      options: options
    )
    authTask = Task { await observeAuthState() }
  }
  
  deinit {
    authTask?.cancel()
  }
  
  /// 監聽 auth 狀態變化並更新 session
  /// 根據最新 SDK 規範，需要檢查 session 是否過期
  private func observeAuthState() async {
    for await (_, session) in client.auth.authStateChanges {
      // 如果 session 存在但已過期，設為 nil（視為未登入）
      if let session = session, session.isExpired {
        self.session = nil
      } else {
        self.session = session
      }
    }
  }
  
  /// 登入（email + 密碼）
  func signIn(email: String, password: String) async {
    guard !email.isEmpty, !password.isEmpty else {
      errorMessage = "請輸入 Email 與密碼"
      return
    }
    errorMessage = nil
    isLoading = true
    defer { isLoading = false }
    
    do {
      _ = try await client.auth.signIn(email: email, password: password)
      // session 會由 authStateChanges 自動更新
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  /// 註冊（email + 密碼）
  func signUp(email: String, password: String) async {
    guard !email.isEmpty, !password.isEmpty else {
      errorMessage = "請輸入 Email 與密碼"
      return
    }
    errorMessage = nil
    isLoading = true
    defer { isLoading = false }
    
    do {
      _ = try await client.auth.signUp(email: email, password: password)
      // 若 Supabase 需 email 確認，這裡可能尚未有 session，需引導使用者去收信
      if session == nil {
        errorMessage = "請到信箱點擊確認連結後再登入"
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  /// Google 登入（使用 Google Sign-In SDK）
  func signInWithGoogle() async {
    errorMessage = nil
    isLoading = true
    defer { isLoading = false }
    
    do {
      // 取得當前視窗場景和 root view controller
      // 在 SwiftUI 中，需要從 connectedScenes 取得 windowScene
      let scenes = UIApplication.shared.connectedScenes
      let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
      
      guard let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first,
            let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? 
            windowScene.windows.first?.rootViewController else {
        errorMessage = "無法取得視窗場景，請稍後再試"
        return
      }
      
      // 從 Info.plist 讀取 REVERSED_CLIENT_ID（URL Types）
      // REVERSED_CLIENT_ID 格式：com.googleusercontent.apps.CLIENT_ID_PREFIX
      // Client ID 格式：CLIENT_ID_PREFIX.apps.googleusercontent.com
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
              // 提取 Client ID prefix
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
      
      // 啟動 Google 登入流程（會喚起系統授權視窗）
      // 注意：使用 iOS Client ID (從 REVERSED_CLIENT_ID 提取)
      let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
      
      // 取得 idToken 和 accessToken
      guard let idToken = result.user.idToken?.tokenString else {
        errorMessage = "無法取得 Google ID Token"
        return
      }
      
      // 取得 accessToken（用於 Supabase 驗證，解決 audience 不匹配問題）
      let accessToken = result.user.accessToken.tokenString
      
      // 將 idToken 和 accessToken 傳送給 Supabase 進行驗證
      // Supabase Auth 會解碼 JWT，將 Google 的 email 寫入 auth.users，並將 name/full_name/picture 等寫入 user_metadata
      _ = try await client.auth.signInWithIdToken(
        credentials: .init(
          provider: .google,
          idToken: idToken,
          accessToken: accessToken
        )
      )
      
      // session 會由 authStateChanges 自動更新
      // 當 session 更新後，isLoggedIn 會變為 true，App 會自動跳轉至 MainTabView
      
    } catch {
      errorMessage = error.localizedDescription
      print("❌ Google 登入錯誤: \(error)")
    }
  }
  
  /// 登出
  func signOut() async {
    errorMessage = nil
    clearAppGroupProfile()
    do {
      try await client.auth.signOut()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
  
  /// 將目前使用者的 displayName、avatarURL 寫入 App Group UserDefaults（供 Widget 等讀取，僅在主線程呼叫）
  func saveProfileToAppGroup(displayName: String, avatarURL: String?) {
    guard let defaults = appGroupDefaults else { return }
    defaults.set(displayName, forKey: Self.appGroupKeys.displayName)
    defaults.set(avatarURL, forKey: Self.appGroupKeys.avatarURL)
    if let id = currentUserId {
      defaults.set(id.uuidString, forKey: Self.appGroupKeys.userId)
    }
  }
  
  /// 從 App Group 讀取上次寫入的 displayName、avatarURL
  func loadProfileFromAppGroup() -> (displayName: String?, avatarURL: String?) {
    guard let defaults = appGroupDefaults else { return (nil, nil) }
    let name = defaults.string(forKey: Self.appGroupKeys.displayName)
    let url = defaults.string(forKey: Self.appGroupKeys.avatarURL)
    return (name, url)
  }
  
  /// 登出時清除 App Group 中的 profile 快取
  private func clearAppGroupProfile() {
    guard let defaults = appGroupDefaults else { return }
    defaults.removeObject(forKey: Self.appGroupKeys.displayName)
    defaults.removeObject(forKey: Self.appGroupKeys.avatarURL)
    defaults.removeObject(forKey: Self.appGroupKeys.userId)
  }
  
  /// 強制以目前 Auth session 的 userMetadata 同步到 Supabase user_profiles 與 App Group（登入成功或 App 啟動時呼叫）
  /// 若 session 中有 full_name / name 或 picture / avatar_url，則 upsert 到資料庫並寫入 App Group
  func syncProfileFromAuthToSupabaseAndAppGroup() async {
    guard let userId = currentUserId else { return }
    let (displayName, avatarURL) = metadataDisplayNameAndAvatar()
    let name = (displayName ?? currentUserDisplayName) ?? "使用者"
    let finalName = name.isEmpty ? "使用者" : name
    let avatar = avatarURL ?? currentUserAvatarURL
    
    // 寫入 App Group（與 Widget 一致）
    saveProfileToAppGroup(displayName: finalName, avatarURL: avatar)
    
    // 依 user_id 更新或插入，避免 upsert 預設用 primary key 導致 duplicate key on user_id
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
      let insertPayload = ProfileInsert(user_id: userId, display_name: finalName, avatar_url: avatar, updated_at: Date())
      do {
        try await client.from("user_profiles").insert(insertPayload).execute()
      } catch {
        // 已存在則改為 update
        let updatePayload = ProfileUpdate(display_name: finalName, avatar_url: avatar, updated_at: Date())
        try await client
          .from("user_profiles")
          .update(updatePayload)
          .eq("user_id", value: userId)
          .execute()
      }
      print("✅ [Auth] 已強制同步 display_name、avatar_url 至 Supabase 與 App Group")
    } catch {
      print("⚠️ [Auth] 同步 user_profiles 失敗: \(error.localizedDescription)")
    }
  }
  
  /// 將指定的 displayName、avatarURL 寫入 Supabase user_profiles 與 App Group（供 ProfileViewModel 等呼叫）
  func syncProfileToRemote(displayName: String, avatarURL: String?) async {
    guard let userId = currentUserId else { return }
    let finalName = displayName.isEmpty ? "使用者" : displayName
    saveProfileToAppGroup(displayName: finalName, avatarURL: avatarURL)
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
      let insertPayload = ProfileInsert(user_id: userId, display_name: finalName, avatar_url: avatarURL, updated_at: Date())
      do {
        try await client.from("user_profiles").insert(insertPayload).execute()
      } catch {
        let updatePayload = ProfileUpdate(display_name: finalName, avatar_url: avatarURL, updated_at: Date())
        try await client.from("user_profiles").update(updatePayload).eq("user_id", value: userId).execute()
      }
      print("✅ [Auth] 已同步 profile 至遠端")
    } catch {
      print("⚠️ [Auth] 同步 user_profiles 失敗: \(error.localizedDescription)")
    }
  }
  
  /// 處理 Google Sign-In callback URL（從 App 的 onOpenURL 呼叫）
  func handleAuthCallback(url: URL) {
    // Google Sign-In SDK 會自動處理 URL callback
    GIDSignIn.sharedInstance.handle(url)
  }
  
  /// 使用 idToken 與 Supabase 連動（供 LoginView 呼叫）
  /// 同時傳遞 accessToken 以解決 iOS Client ID 與 Web Client ID 的 audience 不匹配問題
  /// 注意：不傳遞 nonce 參數，讓 Supabase 端的「Skip nonce checks」生效
  func signInWithIdToken(provider: OpenIDConnectCredentials.Provider, idToken: String, accessToken: String) async throws {
    _ = try await client.auth.signInWithIdToken(
      credentials: .init(
        provider: provider,
        idToken: idToken,
        accessToken: accessToken
        // 不傳遞 nonce，讓 Supabase 後台的「Skip nonce checks」設定生效
      )
    )
    // session 會由 authStateChanges 自動更新
  }
  
  /// 取得當前用戶的顯示名稱（從 Supabase session 的 user_metadata，Google 登入後通常有 full_name 或 name）
  var currentUserDisplayName: String? {
    guard let session = session else { return nil }
    let metadata = session.user.userMetadata
    return metadata["full_name"]?.stringValue
      ?? metadata["name"]?.stringValue
      ?? session.user.email?.components(separatedBy: "@").first
  }
  
  /// 取得當前用戶的頭貼 URL（從 Supabase session 的 user_metadata，Google 登入後通常有 picture 或 avatar_url）
  var currentUserAvatarURL: String? {
    guard let session = session else { return nil }
    let metadata = session.user.userMetadata
    return metadata["avatar_url"]?.stringValue
      ?? metadata["picture"]?.stringValue
  }
  
  /// 從目前 session 的 userMetadata 擷取 full_name 與 avatar URL（供登入後同步到 user_profiles）
  func metadataDisplayNameAndAvatar() -> (displayName: String?, avatarURL: String?) {
    guard let session = session else { return (nil, nil) }
    let metadata = session.user.userMetadata
    let name = metadata["full_name"]?.stringValue
      ?? metadata["name"]?.stringValue
      ?? session.user.email?.components(separatedBy: "@").first
    let avatar = metadata["avatar_url"]?.stringValue ?? metadata["picture"]?.stringValue
    return (name, avatar)
  }
  
  /// 取得 Supabase client（給其他功能打 API 用）
  func getClient() -> SupabaseClient {
    client
  }
}
