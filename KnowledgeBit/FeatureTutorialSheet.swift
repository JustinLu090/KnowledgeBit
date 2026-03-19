import SwiftUI

enum AppGuideFeature: String, Identifiable, CaseIterable {
  case wordSets
  case quiz
  case achievements

  var id: String { rawValue }

  var title: String {
    switch self {
    case .wordSets: return "建立單字集"
    case .quiz: return "測驗模式"
    case .achievements: return "成就系統"
    }
  }

  var tint: Color {
    switch self {
    case .wordSets: return .blue
    case .quiz: return .orange
    case .achievements: return .purple
    }
  }
}

struct FeatureTutorialSheet: View {
  let feature: AppGuideFeature
  @Environment(\.dismiss) private var dismiss
  @State private var stepIndex: Int = 0

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        TutorialHero(feature: feature)

        TabView(selection: $stepIndex) {
          ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
            TutorialStepCard(step: step, tint: feature.tint)
              .padding(.horizontal, 18)
              .tag(idx)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))

        HStack(spacing: 12) {
          Button("上一步") {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
              stepIndex = max(0, stepIndex - 1)
            }
          }
          .buttonStyle(.bordered)
          .disabled(stepIndex == 0)

          Button(stepIndex == steps.count - 1 ? "完成" : "下一步") {
            if stepIndex == steps.count - 1 {
              dismiss()
            } else {
              withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                stepIndex += 1
              }
            }
          }
          .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle(feature.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .presentationDetents([.large])
    .presentationCornerRadius(24)
  }

  private var steps: [TutorialStep] {
    switch feature {
    case .wordSets:
      return [
        TutorialStep(
          title: "點擊「＋」建立單字集",
          caption: "在「單字集」頁面右上角新增。",
          illustration: AnyView(MockTopBarPlus(tint: feature.tint))
        ),
        TutorialStep(
          title: "命名與選擇等級",
          caption: "用主題命名更好找，例如：TOEIC、日文 N5。",
          illustration: AnyView(MockWordSetForm(tint: feature.tint))
        ),
        TutorialStep(
          title: "新增第一張單字卡",
          caption: "輸入「定義 / 例句」，開始累積。",
          illustration: AnyView(MockAddCard(tint: feature.tint))
        )
      ]
    case .quiz:
      return [
        TutorialStep(
          title: "打開任一單字集",
          caption: "從清單進入詳細頁。",
          illustration: AnyView(MockWordSetList(tint: feature.tint))
        ),
        TutorialStep(
          title: "點「開始測驗 / 選擇題測驗」",
          caption: "選擇題會顯示進度與選項。",
          illustration: AnyView(MockWordSetDetailQuizBar(tint: feature.tint))
        ),
        TutorialStep(
          title: "用進度追蹤表現",
          caption: "看分數、正確率，持續強化。",
          illustration: AnyView(MockQuizProgress(tint: feature.tint))
        )
      ]
    case .achievements:
      return [
        TutorialStep(
          title: "完成測驗獲得 EXP",
          caption: "越常練習，成長越快。",
          illustration: AnyView(MockExpGain(tint: feature.tint))
        ),
        TutorialStep(
          title: "到「個人」查看成就",
          caption: "在設定中點「查看成就」開啟統計。",
          illustration: AnyView(MockProfileAchievementsRow(tint: feature.tint))
        ),
        TutorialStep(
          title: "追蹤本週統計",
          caption: "查看 EXP 圖表與選擇題答對率。",
          illustration: AnyView(MockStatsCard(tint: feature.tint))
        )
      ]
    }
  }
}

private struct TutorialStep: Identifiable {
  let id = UUID()
  let title: String
  let caption: String
  let illustration: AnyView
}

private struct TutorialHero: View {
  let feature: AppGuideFeature

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(feature.tint.opacity(0.18))
        Image(systemName: iconName)
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(feature.tint)
      }
      .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: 2) {
        Text(feature.title)
          .font(.headline.weight(.semibold))
        Text("左右滑動查看步驟")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
  }

  private var iconName: String {
    switch feature {
    case .wordSets: return "books.vertical.fill"
    case .quiz: return "checkmark.seal.fill"
    case .achievements: return "trophy.fill"
    }
  }
}

private struct TutorialStepCard: View {
  let step: TutorialStep
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(step.title)
          .font(.title3.weight(.bold))
        Text(step.caption)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }

      step.illustration
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
        )

      Spacer(minLength: 0)
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}

// MARK: - Mock illustrations (visual, lightweight, animatable)

private struct MockTopBarPlus: View {
  let tint: Color
  @State private var pulse = false

  var body: some View {
    HStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(.systemGray5))
        .frame(width: 120, height: 16)
      Spacer()
      ZStack {
        Circle()
          .fill(tint.opacity(0.25))
          .frame(width: 44, height: 44)
          .scaleEffect(pulse ? 1.05 : 0.92)
          .opacity(pulse ? 1 : 0.6)
        Circle()
          .fill(tint)
          .frame(width: 36, height: 36)
        Image(systemName: "plus")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(.white)
      }
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
        pulse = true
      }
    }
  }
}

private struct MockWordSetForm: View {
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("新增單字集", systemImage: "book.fill")
        .font(.headline)
        .foregroundStyle(.primary)

      RoundedRectangle(cornerRadius: 10)
        .fill(Color(.systemGray6))
        .frame(height: 44)
        .overlay(alignment: .leading) {
          Text("例如：日文 N5")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
        }

      HStack(spacing: 8) {
        ForEach(["初級", "中級", "高級"], id: \.self) { t in
          Text(t)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(t == "初級" ? tint.opacity(0.18) : Color(.systemGray6))
            .foregroundStyle(t == "初級" ? tint : .secondary)
            .clipShape(Capsule())
        }
      }
    }
  }
}

private struct MockAddCard: View {
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("新增單字", systemImage: "square.and.pencil")
          .font(.headline)
        Spacer()
        Image(systemName: "sparkles")
          .foregroundStyle(tint)
      }

      RoundedRectangle(cornerRadius: 10)
        .fill(Color(.systemGray6))
        .frame(height: 36)
        .overlay(alignment: .leading) {
          Text("單字 / 片語")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
        }

      RoundedRectangle(cornerRadius: 10)
        .fill(Color(.systemGray6))
        .frame(height: 60)
        .overlay(alignment: .leading) {
          Text("定義 / 例句…")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
        }

      HStack {
        Spacer()
        Text("儲存")
          .font(.callout.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(tint, in: Capsule())
      }
    }
  }
}

private struct MockWordSetList: View {
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("單字集")
        .font(.headline)
      ForEach(0..<3, id: \.self) { i in
        HStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(i == 0 ? tint.opacity(0.2) : Color(.systemGray6))
            .frame(width: 42, height: 42)
            .overlay {
              Image(systemName: "book.fill")
                .foregroundStyle(i == 0 ? tint : .secondary)
            }
          VStack(alignment: .leading, spacing: 2) {
            Text(i == 0 ? "TOEIC 核心" : (i == 1 ? "日文 N5" : "片語整理"))
              .font(.callout.weight(.semibold))
            Text("共 24 個單字")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
      }
    }
  }
}

private struct MockWordSetDetailQuizBar: View {
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("單字集詳細頁")
        .font(.headline)
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.systemGray6))
        .frame(height: 120)
        .overlay(alignment: .center) {
          Text("Cards List…")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

      HStack(spacing: 10) {
        mockButton("開始測驗", systemImage: "play.fill", color: .blue)
        mockButton("選擇題測驗", systemImage: "list.bullet.rectangle.fill", color: tint)
        mockButton("對戰", systemImage: "flag.2.crossed.fill", color: .purple)
      }
    }
  }

  private func mockButton(_ title: String, systemImage: String, color: Color) -> some View {
    VStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.system(size: 14, weight: .semibold))
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .foregroundStyle(.white)
    .background(color.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

private struct MockQuizProgress: View {
  let tint: Color
  @State private var progress: CGFloat = 0.25

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Question 2 / 8")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text("25%")
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray6))
          RoundedRectangle(cornerRadius: 8)
            .fill(tint)
            .frame(width: geo.size.width * progress)
        }
      }
      .frame(height: 10)

      RoundedRectangle(cornerRadius: 16)
        .fill(Color(.systemGray6))
        .frame(height: 110)
        .overlay {
          Text("題目卡片…")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

      HStack(spacing: 8) {
        ForEach(0..<4, id: \.self) { i in
          RoundedRectangle(cornerRadius: 12)
            .fill(i == 1 ? tint.opacity(0.2) : Color(.systemGray6))
            .overlay(alignment: .leading) {
              Text(["A", "B", "C", "D"][i] + " 選項")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
            }
            .frame(height: 34)
        }
      }
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
        progress = 0.72
      }
    }
  }
}

private struct MockExpGain: View {
  let tint: Color
  @State private var bump = false

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Text("完成測驗")
          .font(.headline)
        Spacer()
        Text("+20 EXP")
          .font(.callout.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(tint, in: Capsule())
          .scaleEffect(bump ? 1.03 : 0.96)
      }

      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.systemGray6))
        .frame(height: 10)
        .overlay(alignment: .leading) {
          RoundedRectangle(cornerRadius: 12)
            .fill(tint)
            .frame(width: 180, height: 10)
        }

      Text("累積 EXP 會提升等級與解鎖成就統計。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineSpacing(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
        bump = true
      }
    }
  }
}

private struct MockProfileAchievementsRow: View {
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("個人 > 設定")
        .font(.headline)
      HStack(spacing: 12) {
        Image(systemName: "chart.bar.fill")
          .foregroundStyle(tint)
          .frame(width: 28)
        Text("查看成就")
          .font(.callout.weight(.semibold))
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(.tertiary)
      }
      .padding(12)
      .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
    }
  }
}

private struct MockStatsCard: View {
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("本週每日 EXP")
        .font(.headline)
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(.systemGray6))
        .frame(height: 110)
        .overlay(alignment: .bottomLeading) {
          HStack(alignment: .bottom, spacing: 6) {
            ForEach([6, 8, 12, 24, 36, 18, 10], id: \.self) { v in
              RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(0.9))
                .frame(width: 12, height: CGFloat(v) * 2.3)
            }
          }
          .padding(12)
        }

      HStack(spacing: 14) {
        ZStack {
          Circle()
            .stroke(Color(.systemGray5), lineWidth: 10)
            .frame(width: 70, height: 70)
          Circle()
            .trim(from: 0, to: 0.62)
            .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 70, height: 70)
          Text("62%")
            .font(.headline.weight(.bold))
        }
        VStack(alignment: .leading, spacing: 2) {
          Text("選擇題答對率")
            .font(.callout.weight(.semibold))
          Text("只計入選擇題測驗結果。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
    }
  }
}

#Preview {
  FeatureTutorialSheet(feature: .wordSets)
}

