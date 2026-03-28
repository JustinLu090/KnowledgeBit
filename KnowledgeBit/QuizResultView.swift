import SwiftUI

struct QuizResultView: View {
  let rememberedCards: Int
  let totalCards: Int
  let streakDays: Int?  // optional
  let onFinish: () -> Void
  let onRetry: () -> Void

  /// 可選：傳入後才顯示「發送挑戰」按鈕
  var wordSetId: UUID? = nil
  var wordSetTitle: String? = nil
  var timeSpent: TimeInterval = 0
  /// 本次測驗的卡片 ID 清單（已洗牌順序），用於固定題目挑戰
  var cardIds: [UUID] = []
  /// AI 生成的完整題目快照，傳入後存進 Supabase 供 B 直接使用
  var quizContent: [ChoiceQuestion]? = nil

  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var questService: DailyQuestService
  @EnvironmentObject var authService: AuthService

  @State private var trophyScale: CGFloat = 0.5
  @State private var showContent: Bool = false
  @State private var didGrantExp: Bool = false // 防止重複加 EXP

  // 挑戰相關狀態
  @State private var isCreatingChallenge = false
  @State private var challengeURL: URL?
  @State private var challengeErrorMessage: String?
  @State private var showChallengeError = false
  
  // Calculate accuracy percentage
  private var accuracyPercentage: Int {
    guard totalCards > 0 else { return 0 }
    return Int(Double(rememberedCards) / Double(totalCards) * 100)
  }
  
  // Motivational message based on accuracy
  private var motivationalMessage: String {
    switch accuracyPercentage {
    case 80...100:
      return "太厲害了！維持這個節奏 👍"
    case 50..<80:
      return "不錯喔，再複習幾次會更熟～"
    default:
      return "先記住這幾張就很棒了，明天再來挑戰 💪"
    }
  }
  
  var body: some View {
    ZStack {
      // Background gradient
      LinearGradient(
        colors: [
          Color(.systemGroupedBackground),
          Color(.systemGroupedBackground).opacity(0.8)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
      
      ScrollView {
        VStack(spacing: 0) {
          Spacer()
            .frame(height: 40)
          
          // Trophy icon with animation
          Image(systemName: "trophy.fill")
            .font(.system(size: 100))
            .foregroundStyle(
              LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .scaleEffect(trophyScale)
            .shadow(color: .yellow.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.bottom, 20)
          
          // Title
          Text("測驗完成！")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.bottom, 24)
          
          // Summary card
          VStack(alignment: .leading, spacing: 16) {
            // Cards remembered / total
            HStack {
              Text("你記住了")
                .font(.body)
                .foregroundStyle(.secondary)
              Spacer()
              Text("\(rememberedCards) / \(totalCards) 張卡片")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            }
            
            Divider()
            
            // Accuracy percentage
            HStack {
              Text("正確率")
                .font(.body)
                .foregroundStyle(.secondary)
              Spacer()
              Text("\(accuracyPercentage)%")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(accuracyColor)
            }
            
            // Streak (if available)
            if let streak = streakDays, streak > 0 {
              Divider()
              HStack {
                Image(systemName: "flame.fill")
                  .foregroundStyle(.orange)
                  .font(.body)
                Text("連續學習")
                  .font(.body)
                  .foregroundStyle(.secondary)
                Spacer()
                Text("\(streak) 天")
                  .font(.title3)
                  .fontWeight(.semibold)
                  .foregroundStyle(.primary)
              }
            }
            
            Divider()
            
            // Motivational message
            HStack {
              Text(motivationalMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
              Spacer()
            }
          }
          .padding(20)
          .background(Color(.secondarySystemGroupedBackground))
          .cornerRadius(16)
          .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
          .padding(.horizontal, 24)
          .opacity(showContent ? 1 : 0)
          .offset(y: showContent ? 0 : 20)
          
          Spacer()
            .frame(height: 60)
        }
      }
      
      // Bottom buttons
      VStack {
        Spacer()
        
        VStack(spacing: 12) {
          // Primary finish button
          Button(action: onFinish) {
            Text("完成")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(Color.accentColor)
              .cornerRadius(16)
          }

          // 發送挑戰按鈕（僅在有指定 wordSet 時顯示）
          if let wsId = wordSetId, let wsTitle = wordSetTitle {
            if let url = challengeURL {
              // 挑戰已建立 → 顯示分享按鈕
              ShareLink(
                item: url,
                subject: Text("KnowledgeBit 挑戰"),
                message: Text("我在「\(wsTitle)」答對了 \(rememberedCards)/\(totalCards) 題，你能超越我嗎？")
              ) {
                Label("分享挑戰連結", systemImage: "square.and.arrow.up")
                  .font(.headline)
                  .foregroundStyle(.white)
                  .frame(maxWidth: .infinity)
                  .frame(height: 56)
                  .background(Color.orange)
                  .cornerRadius(16)
              }
            } else {
              // 尚未建立挑戰
              Button(action: {
                Task { await createChallenge(wordSetId: wsId, wordSetTitle: wsTitle) }
              }) {
                HStack {
                  if isCreatingChallenge {
                    ProgressView().tint(.white)
                  } else {
                    Image(systemName: "flag.fill")
                  }
                  Text(isCreatingChallenge ? "建立中…" : "發送挑戰給好友")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.orange)
                .cornerRadius(16)
              }
              .disabled(isCreatingChallenge)
            }
          }

          // Secondary retry button
          Button(action: onRetry) {
            Text("再挑戰一次")
              .font(.body)
              .foregroundStyle(Color.accentColor)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .background(
          LinearGradient(
            colors: [
              Color(.systemGroupedBackground).opacity(0),
              Color(.systemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 150)
          .offset(y: 50)
        )
      }
    }
    .onAppear {
      // Trophy bounce animation
      withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
        trophyScale = 1.0
      }

      // Content fade-in with delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        withAnimation(.easeOut(duration: 0.5)) {
          showContent = true
        }
      }

      // 給予 EXP（只執行一次）
      if !didGrantExp {
        grantExperience()
        didGrantExp = true
      }
    }
    .alert("挑戰建立失敗", isPresented: $showChallengeError) {
      Button("確定", role: .cancel) {}
    } message: {
      Text(challengeErrorMessage ?? "請稍後再試")
    }
  }

  // MARK: - 建立挑戰

  private func createChallenge(wordSetId: UUID, wordSetTitle: String) async {
    isCreatingChallenge = true
    let service = ChallengeService(authService: authService)
    do {
      let id = try await service.createChallenge(
        wordSetId: wordSetId,
        wordSetTitle: wordSetTitle,
        score: rememberedCards,
        total: totalCards,
        timeSpent: timeSpent,
        cardIds: cardIds,
        quizContent: quizContent
      )
      challengeURL = ChallengeService.deepLink(for: id)
    } catch {
      challengeErrorMessage = error.localizedDescription
      showChallengeError = true
    }
    isCreatingChallenge = false
  }
  
  // Color based on accuracy
  private var accuracyColor: Color {
    switch accuracyPercentage {
    case 80...100:
      return .green
    case 50..<80:
      return .orange
    default:
      return .red
    }
  }
  
  // 測驗結算不再給予 EXP（僅保留：今日任務・測驗 20、完成三張卡片 10、精準打擊 20）
  private func grantExperience() {
    // 背一張卡片／測驗答對題數不再給分，此處不發放 EXP
  }
}

// MARK: - Preview
#Preview {
  QuizResultView(
    rememberedCards: 8,
    totalCards: 10,
    streakDays: 5,
    onFinish: {},
    onRetry: {}
  )
  .environmentObject(ExperienceStore())
  .environmentObject(DailyQuestService())
}

