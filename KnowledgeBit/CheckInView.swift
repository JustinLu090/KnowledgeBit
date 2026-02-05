// CheckInView.swift
// Check-in view showing the study heatmap

import SwiftUI

struct CheckInView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StudyHeatmapView()
          .padding(.horizontal, 20)
          .padding(.vertical, 20)
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("打卡記錄")
    .navigationBarTitleDisplayMode(.large)
  }
}
