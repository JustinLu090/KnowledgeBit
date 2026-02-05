// AchievementsView.swift
// Achievements/Stats placeholder view

import SwiftUI

struct AchievementsView: View {
  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Spacer()
        
        // Chart icon
        Image(systemName: "chart.bar.fill")
          .font(.system(size: 80))
          .foregroundStyle(
            LinearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
        
        // Coming soon text
        VStack(spacing: 8) {
          Text("學習統計")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.primary)
          
          Text("即將推出")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.secondary)
        }
        
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemGroupedBackground))
      .navigationTitle("成就")
      .navigationBarTitleDisplayMode(.large)
    }
  }
}
