// HomeSharedComponents.swift
// 首頁共用區塊與按鈕（可與其他首頁型畫面共用）

import SwiftUI

// MARK: - Home Header Section

/// 首頁標題 + 右側「新增」Menu（單字、單字集、打卡）
struct HomeHeaderSection: View {
  @Binding var showingAddCardSheet: Bool
  
  var body: some View {
    HStack(alignment: .center) {
      Text("KnowledgeBit")
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(.primary)
      
      Spacer()
      
      Menu {
        Button(action: { showingAddCardSheet = true }) {
          Label("新增單字", systemImage: "plus.circle")
        }
        NavigationLink {
          WordSetListView()
        } label: {
          Label("新增單字集", systemImage: "book.badge.plus")
        }
        NavigationLink {
          CheckInView()
        } label: {
          Label("打卡", systemImage: "calendar")
        }
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(Color.blue)
          .clipShape(Circle())
      }
    }
  }
}

// MARK: - Daily Quiz Button

/// 開始每日測驗按鈕（導向 QuizView）
struct DailyQuizButton: View {
  var body: some View {
    NavigationLink(destination: QuizView()) {
      HStack(spacing: 12) {
        Image(systemName: "play.fill")
          .font(.system(size: 20, weight: .semibold))
        Text("開始每日測驗")
          .font(.system(size: 17, weight: .semibold))
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.blue)
      .cornerRadius(16)
      .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    .buttonStyle(.plain)
  }
}
