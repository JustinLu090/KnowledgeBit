// ProfileView.swift
// Profile tab view with settings integration

import SwiftUI

struct ProfileView: View {
  @State private var showingSettingsSheet = false
  
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
    }
  }
  
  // MARK: - Profile Header
  
  private var profileHeader: some View {
    VStack(spacing: 16) {
      // Avatar
      Circle()
        .fill(
          LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 100, height: 100)
        .overlay {
          Image(systemName: "person.fill")
            .font(.system(size: 50))
            .foregroundStyle(.white)
        }
        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
      
      // Name placeholder
      Text("使用者")
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(.primary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(20)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
        
        Divider()
          .padding(.leading, 16)
        
        HStack {
          Text("版本資訊")
            .font(.system(size: 16))
            .foregroundStyle(.primary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
      }
      .cornerRadius(12)
    }
  }
}
