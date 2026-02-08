// BattleView.swift
// Battle mode placeholder view

import SwiftUI
import Combine

struct BattleView: View {
  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Spacer()
        
        // Trophy icon
        Image(systemName: "trophy.fill")
          .font(.system(size: 80))
          .foregroundStyle(
            LinearGradient(
              colors: [.yellow, .orange],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .shadow(color: .orange.opacity(0.3), radius: 20, x: 0, y: 10)
        
        // Coming soon text
        VStack(spacing: 8) {
          Text("知識王對戰模式")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.primary)
          
          Text("即將啟動")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.secondary)
        }
        
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemGroupedBackground))
      .navigationTitle("對戰")
      .navigationBarTitleDisplayMode(.large)
    }
  }
}
