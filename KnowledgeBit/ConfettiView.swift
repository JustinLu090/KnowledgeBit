// ConfettiView.swift
// 純 SwiftUI 紙屑特效：isActive 從 false → true 時觸發一次

import SwiftUI

// MARK: - Particle Model

private struct ConfettiParticle: Identifiable {
  let id = UUID()
  let xFraction: CGFloat      // 水平起始位置（0～1，相對容器寬度）
  let delay: Double            // 出現延遲（秒）
  let duration: Double         // 下落總時間（秒）
  let color: Color
  let width: CGFloat
  let height: CGFloat
  let initialRotation: Double
  let rotationDelta: Double    // 旋轉變化量（可為負，呈現左右翻轉）
  let xDrift: CGFloat          // 水平飄移量（像素）
}

// MARK: - ConfettiView

/// 紙屑特效層。請放在 ZStack 最上層，設 `allowsHitTesting(false)`。
/// `isActive` 由 false 變為 true 時觸發一次完整動畫。
struct ConfettiView: View {

  let isActive: Bool

  // MARK: - Config

  private static let colors: [Color] = [
    .red, .orange, .yellow, .green, .blue, .purple, .pink,
    Color(red: 1.00, green: 0.84, blue: 0.00),  // gold
    Color(red: 0.00, green: 0.78, blue: 0.78),  // teal
    Color(red: 1.00, green: 0.41, blue: 0.71),  // hot pink
  ]

  // MARK: - State

  @State private var particles: [ConfettiParticle] = []
  @State private var animating = false

  // MARK: - Body

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ForEach(particles) { p in
          RoundedRectangle(cornerRadius: 2)
            .fill(p.color)
            .frame(width: p.width, height: p.height)
            .rotationEffect(
              .degrees(animating
                       ? p.initialRotation + p.rotationDelta
                       : p.initialRotation)
            )
            .position(
              x: p.xFraction * geo.size.width + (animating ? p.xDrift : 0),
              y: animating ? geo.size.height + 50 : -20
            )
            .opacity(animating ? 0 : 1)
            .animation(
              .easeIn(duration: p.duration).delay(p.delay),
              value: animating
            )
        }
      }
    }
    .allowsHitTesting(false)
    .onAppear {
      particles = Self.makeParticles()
      if isActive { trigger() }
    }
    .onChange(of: isActive) { _, active in
      if active {
        // 重置後再觸發，支援多次播放
        particles = Self.makeParticles()
        animating = false
        trigger()
      }
    }
  }

  // MARK: - Helpers

  private func trigger() {
    // 微小延遲確保 reset（animating = false）已生效
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      animating = true
    }
  }

  private static func makeParticles(count: Int = 100) -> [ConfettiParticle] {
    (0..<count).map { _ in
      ConfettiParticle(
        xFraction:       CGFloat.random(in: 0.02...0.98),
        delay:           Double.random(in: 0...1.5),
        duration:        Double.random(in: 1.8...3.2),
        color:           colors.randomElement()!,
        width:           CGFloat.random(in: 6...14),
        height:          CGFloat.random(in: 9...20),
        initialRotation: Double.random(in: 0...360),
        rotationDelta:   Double.random(in: 200...540) * (Bool.random() ? 1 : -1),
        xDrift:          CGFloat.random(in: -80...80)
      )
    }
  }
}

// MARK: - Preview

#Preview {
  ZStack {
    Color.black.ignoresSafeArea()
    ConfettiView(isActive: true)
  }
}
