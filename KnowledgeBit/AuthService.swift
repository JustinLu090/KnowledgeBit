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
    do {
      try await client.auth.signOut()
    } catch {
      errorMessage = error.localizedDescription
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
  
  /// 取得當前用戶的顯示名稱（從 Supabase session）
  var currentUserDisplayName: String? {
    guard let session = session else { return nil }
    let metadata = session.user.userMetadata
    return metadata["full_name"]?.stringValue ?? 
           metadata["name"]?.stringValue ??
           session.user.email?.components(separatedBy: "@").first
  }
  
  /// 取得當前用戶的頭貼 URL（從 Supabase session）
  var currentUserAvatarURL: String? {
    guard let session = session else { return nil }
    let metadata = session.user.userMetadata
    return metadata["avatar_url"]?.stringValue ??
           metadata["picture"]?.stringValue
  }
  
  /// 取得 Supabase client（給其他功能打 API 用）
  func getClient() -> SupabaseClient {
    client
  }
}
