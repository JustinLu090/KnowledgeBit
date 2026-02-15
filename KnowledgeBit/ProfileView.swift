// ProfileView.swift
// Profile tab view with settings integration

import SwiftUI
import SwiftData

struct ProfileView: View {
  @EnvironmentObject var authService: AuthService
  @Environment(\.modelContext) private var modelContext
  @Query private var userProfiles: [UserProfile]
  @StateObject private var profileViewModel = ProfileViewModel()
  @State private var showingSettingsSheet = false
  @State private var showingEditProfileSheet = false
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Profile header
          profileHeader
            .padding(.top, 20)
            .padding(.horizontal, 20)
          
          // Settings section
          settingsSection
            .padding(.horizontal, 20)
          
          // About section
          aboutSection
            .padding(.horizontal, 20)
          
          Spacer()
            .frame(height: 32)
        }
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("個人")
      .navigationBarTitleDisplayMode(.large)
      .sheet(isPresented: $showingSettingsSheet) {
        SettingsView()
      }
      .onAppear {
        let currentProfile = userProfiles.first { $0.userId == authService.currentUserId }
        Task { await profileViewModel.refreshUserProfile(authService: authService, localProfile: currentProfile) }
      }
      .refreshable {
        let currentProfile = userProfiles.first { $0.userId == authService.currentUserId }
        await profileViewModel.refreshUserProfile(authService: authService, localProfile: currentProfile)
      }
    }
  }
  
  // MARK: - Profile Header
  
  private var profileHeader: some View {
    let currentProfile = userProfiles.first { $0.userId == authService.currentUserId }
    // 優先本地 UserProfile，其次 Auth session 的 userMetadata（登入後 Supabase 會寫入 full_name / picture）
    let displayName = currentProfile?.displayName ?? authService.currentUserDisplayName ?? "使用者"
    let avatarURL = currentProfile?.avatarURL ?? authService.currentUserAvatarURL
    
    return VStack(spacing: 16) {
      AvatarView(
        avatarData: currentProfile?.avatarData,
        avatarURL: avatarURL,
        size: 100
      )
      .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
      
      // Name
      Text(displayName)
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(.primary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(20)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    .onTapGesture {
      showingEditProfileSheet = true
    }
    .sheet(isPresented: $showingEditProfileSheet) {
      EditProfileView(
        currentProfile: currentProfile,
        userId: authService.currentUserId
      )
      .environmentObject(authService)
      .onDisappear {
        // 重新載入資料
        try? modelContext.save()
      }
    }
  }
  
  // MARK: - Settings Section
  
  private var settingsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("設定")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)
      
      Button(action: {
        showingSettingsSheet = true
      }) {
        HStack(spacing: 16) {
          Image(systemName: "gearshape.fill")
            .font(.system(size: 20))
            .foregroundStyle(.blue)
            .frame(width: 30)
          
          Text("應用程式設定")
            .font(.system(size: 16))
            .foregroundStyle(.primary)
          
          Spacer()
          
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
      }
      .buttonStyle(.plain)
      
      Button(action: {
        Task { await authService.signOut() }
      }) {
        HStack(spacing: 16) {
          Image(systemName: "rectangle.portrait.and.arrow.right")
            .font(.system(size: 20))
            .foregroundStyle(.red)
            .frame(width: 30)
          
          Text("登出")
            .font(.system(size: 16))
            .foregroundStyle(.red)
          
          Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
      }
      .buttonStyle(.plain)
    }
  }
  
  // MARK: - About Section
  
  private var aboutSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("關於")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)
      
      VStack(spacing: 0) {
        HStack {
          Text("KnowledgeBit")
            .font(.system(size: 16))
            .foregroundStyle(.primary)
          Spacer()
          Text("v1.0")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
      }
      .cornerRadius(12)
    }
  }
}
