import SwiftUI

struct AppGuideView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var activeFeature: AppGuideFeature?

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        Spacer(minLength: 8)

        VStack(spacing: 12) {
          Image(systemName: "lightbulb.fill")
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(.tint)
            .padding(.bottom, 4)

          Text("歡迎使用 KnowledgeBit")
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .multilineTextAlignment(.center)

          Text("建立單字集、開始複習，並用成就追蹤進度。")
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
        }

        VStack(alignment: .leading, spacing: 10) {
          GuideRow(
            systemImage: "books.vertical.fill",
            title: "建立單字集",
            subtitle: "整理主題，快速新增第一張卡片。",
            onTap: { activeFeature = .wordSets }
          )
          GuideRow(
            systemImage: "checkmark.seal.fill",
            title: "測驗模式",
            subtitle: "用測驗檢視成果，強化記憶。",
            onTap: { activeFeature = .quiz }
          )
          GuideRow(
            systemImage: "trophy.fill",
            title: "成就系統",
            subtitle: "用統計追蹤進度與答對率。",
            onTap: { activeFeature = .achievements }
          )
        }
        .padding(.horizontal, 20)

        Spacer(minLength: 10)

        Button {
          dismiss()
        } label: {
          Text("開始使用")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemGroupedBackground))
      .sheet(item: $activeFeature) { feature in
        FeatureTutorialSheet(feature: feature)
      }
    }
  }
}

private struct GuideRow: View {
  let systemImage: String
  let title: String
  let subtitle: String
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: systemImage)
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.tint)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
          Text(subtitle)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.tertiary)
          .padding(.top, 2)
      }
      .padding(12)
      .background(.background)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color(.separator).opacity(0.28), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  AppGuideView()
}

