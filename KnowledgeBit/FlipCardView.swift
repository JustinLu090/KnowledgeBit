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

      // BACK SIDE - Answer (Short Answer)
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
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.blue.opacity(0.1))
        .shadow(radius: 5)

      VStack {
        Text("❓ 問題")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()

        Spacer()

        Text(card.title)
          .font(.title)
          .bold()
          .multilineTextAlignment(.center)
          .padding()

        Spacer()
      }
    }
  }

  // MARK: - Back View (Answer - Short)

  private var backView: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.blue.opacity(0.1))
        .shadow(radius: 5)

      VStack {
        Text("💡 簡答")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()

        Spacer()

        Text(shortAnswerForDisplay)
          .font(.title2.weight(.semibold))
          .multilineTextAlignment(.center)
          .padding()

        Spacer()
      }
    }
  }

  private var shortAnswerForDisplay: String {
    let sa = card.shortAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
    if !sa.isEmpty { return sa }

    // fallback：舊資料 shortAnswer 空 → 用 content 第一行
    let lines = card.content.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
    let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
    let cleaned = first.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "（尚未填寫簡答）" : cleaned
  }
}
