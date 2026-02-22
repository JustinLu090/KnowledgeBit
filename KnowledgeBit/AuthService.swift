// AuthService.swift
// 管理 Supabase 登入狀態，供 App 判斷顯示登入畫面或主畫面

import Foundation
import SwiftUI
import Combine
import Supabase
import GoogleSignIn
import WidgetKit

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
    displayName: AppGroup.Keys.displayName,
    avatarURL: AppGroup.Keys.avatarURL,
    userId: AppGroup.Keys.userId,
    level: AppGroup.Keys.level,
    exp: AppGroup.Keys.exp,
    expToNext: AppGroup.Keys.expToNext
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
    
    let newClient: SupabaseClient = SupabaseClient(
      supabaseURL: SupabaseConfig.url,
      supabaseKey: SupabaseConfig.anonKey,
      options: options
    )
    client = newClient
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
  /// 使用線程安全的寫入方式，確保資料一致性
  /// - Parameters:
  ///   - displayName: 使用者顯示名稱
  ///   - avatarURL: 頭像 URL（可選）
  ///   - shouldReloadWidget: 是否立即觸發 Widget 刷新（預設為 true，批次同步時設為 false）
  func saveProfileToAppGroup(displayName: String, avatarURL: String?, shouldReloadWidget: Bool = true) {
    // 確保在主線程執行
    guard Thread.isMainThread else {
      Task { @MainActor in
        self.saveProfileToAppGroup(displayName: displayName, avatarURL: avatarURL, shouldReloadWidget: shouldReloadWidget)
      }
      return
    }
    
    guard let defaults = appGroupDefaults else {
      print("⚠️ [App Group] sharedUserDefaults 為 nil，請確認 Signing & Capabilities 已設定 App Groups")
      return
    }
    
    // 使用線程安全的方式寫入
    defaults.set(displayName, forKey: Self.appGroupKeys.displayName)
    defaults.set(avatarURL, forKey: Self.appGroupKeys.avatarURL)
    if let id = currentUserId {
      defaults.set(id.uuidString, forKey: Self.appGroupKeys.userId)
    }
    defaults.synchronize() // 確保立即寫入，避免競爭條件
    
    // 只有在需要時才觸發 Widget 刷新（批次同步時由 syncToWidget 統一處理）
    if shouldReloadWidget {
      WidgetReloader.reloadAll()
    }
  }
  
  /// 將使用者的 level、exp、expToNext 寫入 App Group UserDefaults（供 Widget 等讀取，僅在主線程呼叫）
  /// 使用線程安全的寫入方式，確保資料一致性
  /// - Parameters:
  ///   - level: 使用者等級
  ///   - exp: 當前經驗值
  ///   - expToNext: 升級所需經驗值
  ///   - shouldReloadWidget: 是否立即觸發 Widget 刷新（預設為 true，批次同步時設為 false）
  func saveExpToAppGroup(level: Int, exp: Int, expToNext: Int, shouldReloadWidget: Bool = true) {
    // 確保在主線程執行（AuthService 為 @MainActor，但為安全起見再次確認）
    guard Thread.isMainThread else {
      Task { @MainActor in
        self.saveExpToAppGroup(level: level, exp: exp, expToNext: expToNext, shouldReloadWidget: shouldReloadWidget)
      }
      return
    }
    
    guard let defaults = appGroupDefaults else {
      print("⚠️ [App Group] sharedUserDefaults 為 nil，請確認 Signing & Capabilities 已設定 App Groups")
      return
    }
    
    // 使用線程安全的方式寫入（雖然已在主線程，但 synchronize 確保立即寫入磁碟）
    defaults.set(level, forKey: Self.appGroupKeys.level)
    defaults.set(exp, forKey: Self.appGroupKeys.exp)
    defaults.set(expToNext, forKey: Self.appGroupKeys.expToNext)
    defaults.synchronize() // 確保立即寫入，避免競爭條件
    
    print("✅ [App Group] 已同步等級與經驗值 - Level: \(level), EXP: \(exp)/\(expToNext)")
    
    // 只有在需要時才觸發 Widget 刷新（批次同步時由 syncToWidget 統一處理）
    if shouldReloadWidget {
      WidgetReloader.reloadAll()
    }
  }
  
  /// 批次同步所有使用者資料到 App Group（供 Widget 讀取）
  /// 在一次完整的同步流程中，使用此方法可以避免多次觸發 Widget 刷新
  /// - Parameters:
  ///   - displayName: 使用者顯示名稱（可選，nil 時不更新）
  ///   - avatarURL: 頭像 URL（可選，nil 時不更新）
  ///   - level: 使用者等級（可選，nil 時不更新）
  ///   - exp: 當前經驗值（可選，nil 時不更新）
  ///   - expToNext: 升級所需經驗值（可選，nil 時不更新）
  func syncToWidget(
    displayName: String? = nil,
    avatarURL: String? = nil,
    level: Int? = nil,
    exp: Int? = nil,
    expToNext: Int? = nil
  ) {
    // 確保在主線程執行
    guard Thread.isMainThread else {
      Task { @MainActor in
        self.syncToWidget(displayName: displayName, avatarURL: avatarURL, level: level, exp: exp, expToNext: expToNext)
      }
      return
    }
    
    guard let defaults = appGroupDefaults else {
      print("⚠️ [App Group] sharedUserDefaults 為 nil，請確認 Signing & Capabilities 已設定 App Groups")
      return
    }
    
    var hasUpdates = false
    
    // 批次寫入所有需要更新的資料（不立即刷新）
    if let name = displayName {
      defaults.set(name, forKey: Self.appGroupKeys.displayName)
      hasUpdates = true
    }
    
    if let url = avatarURL {
      defaults.set(url, forKey: Self.appGroupKeys.avatarURL)
      hasUpdates = true
    } else if avatarURL == nil && displayName != nil {
      // 如果明確傳入 nil，清除頭像 URL
      defaults.removeObject(forKey: Self.appGroupKeys.avatarURL)
      hasUpdates = true
    }
    
    if let id = currentUserId, (displayName != nil || avatarURL != nil) {
      defaults.set(id.uuidString, forKey: Self.appGroupKeys.userId)
      hasUpdates = true
    }
    
    if let lvl = level {
      defaults.set(lvl, forKey: Self.appGroupKeys.level)
      hasUpdates = true
    }
    
    if let e = exp {
      defaults.set(e, forKey: Self.appGroupKeys.exp)
      hasUpdates = true
    }
    
    if let etn = expToNext {
      defaults.set(etn, forKey: Self.appGroupKeys.expToNext)
      hasUpdates = true
    }
    
    // 只有在有更新時才同步並刷新
    if hasUpdates {
      defaults.synchronize() // 確保立即寫入，避免競爭條件
      print("✅ [App Group] 批次同步完成 - displayName: \(displayName ?? "未更新"), level: \(level?.description ?? "未更新"), exp: \(exp?.description ?? "未更新")")
      
      // 統一觸發一次 Widget 刷新（使用防抖機制）
      WidgetReloader.reloadAll()
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
    defaults.synchronize()
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
    // 不立即刷新，因為可能還有其他資料需要同步（如 EXP、Level）
    saveProfileToAppGroup(displayName: finalName, avatarURL: avatar, shouldReloadWidget: false)
    
    // 依 user_id 更新或插入，避免 upsert 預設用 primary key 導致 duplicate key on user_id
    struct ProfileUpdate: Encodable {
      let display_name: String
      let avatar_url: String?
      let updated_at: Date
      
      enum CodingKeys: String, CodingKey {
        case display_name
        case avatar_url
        case updated_at
      }
    }
    struct ProfileInsert: Encodable {
      let user_id: UUID
      let display_name: String
      let avatar_url: String?
      let updated_at: Date
      
      enum CodingKeys: String, CodingKey {
        case user_id
        case display_name
        case avatar_url
        case updated_at
      }
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
          .eq(AppGroup.SupabaseFields.userId, value: userId)
          .execute()
      }
      print("✅ [Auth] 已強制同步 display_name、avatar_url 至 Supabase 與 App Group")
    } catch {
      print("⚠️ [Auth] 同步 user_profiles 失敗: \(error.localizedDescription)")
    }
  }
  
  /// 上傳頭貼至 Supabase Storage，回傳公開 URL
  /// 需先在 Supabase Dashboard 建立 bucket「avatars」且設為 public
  func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
    guard session != nil else {
      throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登入，無法上傳"])
    }
    let path = "\(userId.uuidString)/avatar.jpg"
    #if DEBUG
    print("📤 [UploadAvatar] path=\(path), userId=\(userId.uuidString)")
    #endif
    let bucket = "avatars"  // 需與 Dashboard 的 bucket 名稱完全一致（含大小寫）
    _ = try await client.storage
      .from(bucket)
      .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))
    let publicURL = try client.storage.from(bucket).getPublicURL(path: path)
    return publicURL.absoluteString
  }

  /// 將指定的 displayName、avatarURL 寫入 Supabase user_profiles 與 App Group（供 ProfileViewModel 等呼叫）
  func syncProfileToRemote(displayName: String, avatarURL: String?) async {
    guard let userId = currentUserId else { return }
    let finalName = displayName.isEmpty ? "使用者" : displayName
    saveProfileToAppGroup(displayName: finalName, avatarURL: avatarURL)
    struct ProfileUpsert: Encodable {
      let user_id: UUID
      let display_name: String
      let avatar_url: String?
      let updated_at: Date
      
      enum CodingKeys: String, CodingKey {
        case user_id
        case display_name
        case avatar_url
        case updated_at
      }
    }
    do {
      let payload = ProfileUpsert(user_id: userId, display_name: finalName, avatar_url: avatarURL, updated_at: Date())
      try await client.from("user_profiles")
        .upsert(payload, onConflict: AppGroup.SupabaseFields.userId)
        .execute()
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
