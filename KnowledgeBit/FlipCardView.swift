// FlipCardView.swift
// 3D flip card view with separate front and back sides to prevent text mirroring

import SwiftUI

struct FlipCardView: View {
  let card: Card
  @Binding var isFlipped: Bool
  
  var body: some View {
    ZStack {
      // FRONT SIDE - Question
      frontView
        .opacity(isFlipped ? 0 : 1)
        .rotation3DEffect(
          .degrees(isFlipped ? 180 : 0),
          axis: (x: 0, y: 1, z: 0),
          perspective: 0.8
        )
      
      // BACK SIDE - Answer
      backView
        .opacity(isFlipped ? 1 : 0)
        .rotation3DEffect(
          .degrees(isFlipped ? 0 : -180),
          axis: (x: 0, y: 1, z: 0),
          perspective: 0.8
        )
    }
    .animation(.spring(), value: isFlipped)
  }
  
  // MARK: - Front View (Question)
  
  private var frontView: some View {
    ZStack {
      // Background
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.blue.opacity(0.1))
        .shadow(radius: 5)
      
      VStack {
        // Top label - aligned to leading
        Text("❓ 問題")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        
        Spacer()
        
        // Center question text
        Text(card.title)
          .font(.title)
          .bold()
          .multilineTextAlignment(.center)
          .padding()
        
        Spacer()
      }
    }
  }
  
  // MARK: - Back View (Answer)
  
  private var backView: some View {
    ZStack {
      // Background (same style as front)
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.blue.opacity(0.1))
        .shadow(radius: 5)
      
      VStack {
        // Top label - aligned to leading
        Text("💡 答案")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        
        Spacer()
        
        // Center answer text
        Text(card.content)
          .font(.title)
          .bold()
          .multilineTextAlignment(.center)
          .padding()
        
        Spacer()
      }
    }
  }
}

