// StrategicGridCellView.swift
// Color policy: ONLY ownership colors (player/enemy/neutral). No brightness-changing overlays.

import SwiftUI

struct StrategicGridCellView: View {
  enum BorderState: Equatable {
    case none
    case neighbor    // white dashed border
    case selected    // strong white border
  }

  let size: CGFloat
  let baseColor: Color
  let hpFraction: CGFloat
  let pendingLabel: Int
  let borderState: BorderState

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(baseColor)

      if pendingLabel > 0 {
        VStack {
          HStack {
            Text("+\(pendingLabel)")
              .font(.system(size: 12, weight: .bold, design: .rounded))
              .foregroundStyle(.white.opacity(0.92))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(.black.opacity(0.25), in: Capsule())
            Spacer()
          }
          Spacer()
        }
        .padding(8)
      }

      VStack {
        Spacer()
        GeometryReader { geo in
          let w = geo.size.width
          ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.10))
            Capsule()
              .fill(Color.white.opacity(0.70))
              .frame(width: max(4, w * max(0, min(1, hpFraction))))
          }
        }
        .frame(height: 6)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
      }

      borderOverlay
    }
    .frame(width: size, height: size)
    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  @ViewBuilder
  private var borderOverlay: some View {
    switch borderState {
    case .none:
      EmptyView()

    case .neighbor:
      AnimatedDashedBorder()
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(1)

    case .selected:
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.white.opacity(0.95), lineWidth: 3)
        .shadow(color: .white.opacity(0.35), radius: 14, x: 0, y: 0)
        .padding(0)
    }
  }
}

private struct AnimatedDashedBorder: View {
  @State private var phase: CGFloat = 0

  var body: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
      .stroke(
        Color.white.opacity(0.9),
        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 6], dashPhase: phase)
      )
      .shadow(color: .white.opacity(0.25), radius: 10, x: 0, y: 0)
      .onAppear {
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
          phase = -28
        }
      }
  }
}
