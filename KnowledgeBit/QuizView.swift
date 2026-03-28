import SwiftUI
import SwiftData
import Combine

// MARK: - Voice State

private enum VoiceState: Equatable {
  case idle       // 等待使用者按下麥克風
  case listening  // STT 辨識中
  case matched    // 答對，準備自動前進
  case missed     // 答錯，顯示正確答案
}

struct QuizView: View {
  // Optional: specific cards to quiz (e.g., from a WordSet)
  // If nil, uses @Query to fetch all cards
  var cards: [Card]? = nil
  /// WordSet 的 BCP-47 語言代碼，供 TTS / STT 使用（例如 "en-US", "ja-JP"）
  var language: String? = nil
  /// 供「發送挑戰」功能使用；nil 時隱藏挑戰按鈕
  var wordSetId: UUID? = nil
  var wordSetTitle: String? = nil

  // Fallback query for all cards if cards parameter is nil
  @Query(sort: \Card.createdAt, order: .reverse) private var allCards: [Card]

  // Query for StudyLogs to calculate streak
  @Query(sort: \StudyLog.date, order: .reverse) private var logs: [StudyLog]

  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var taskService: TaskService
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var questService: DailyQuestService
  @EnvironmentObject var authService: AuthService

  // 測驗狀態
  @State private var currentCardIndex = 0
  @State private var isFlipped = false
  @State private var showResult = false
  @State private var score = 0
  @State private var showExitConfirmation = false
  @State private var shuffledCards: [Card] = []
  @State private var sessionStartTime = Date()
  /// 測驗總耗時（秒），於 showResult 觸發時記錄，傳給 QuizResultView
  @State private var quizTimeSpent: TimeInterval = 0

  // TTS / STT 狀態
  @AppStorage("tts_auto_speak") private var ttsAutoSpeak = false
  @State private var isVoiceMode = false
  @State private var voiceState: VoiceState = .idle
  @State private var showPermissionAlert = false

  @StateObject private var speech = SpeechService()

  private let srsService = SRSService()

  private var cardsToUse: [Card] {
    if let specificCards = cards { return specificCards }
    let dueCards = srsService.getDueCards(now: Date(), context: modelContext)
    return dueCards.isEmpty ? allCards : dueCards
  }

  private var currentStreak: Int { logs.currentStreak() }

  var body: some View {
    Group {
      if showResult {
        QuizResultView(
          rememberedCards: score,
          totalCards: shuffledCards.count,
          streakDays: currentStreak,
          onFinish: {
            saveStudyLog()
            let sessionMinutes = max(0, Int(Date().timeIntervalSince(sessionStartTime) / 60))
            if sessionMinutes > 0 {
              questService.recordStudyMinutes(sessionMinutes, experienceStore: experienceStore)
            }
            let isWordSetQuiz = (cards != nil && !(cards ?? []).isEmpty)
            if isWordSetQuiz {
              questService.recordWordSetCompleted(experienceStore: experienceStore)
              let total = shuffledCards.count
              let accuracy = total > 0 ? Int(Double(score) / Double(total) * 100) : 0
              questService.recordWordSetQuizResult(
                accuracyPercent: accuracy,
                isPerfect: (total > 0 && score == total),
                quizType: .general,
                experienceStore: experienceStore)
            } else {
              if taskService.completeQuizTask(experienceStore: experienceStore) {
                questService.recordExpGainedToday(20, experienceStore: experienceStore)
              }
            }
            dismiss()
          },
          onRetry: { retryQuiz() },
          wordSetId: wordSetId,
          wordSetTitle: wordSetTitle,
          timeSpent: quizTimeSpent
        )
      } else {
        quizInProgressView
      }
    }
    .alert("確定要退出嗎？", isPresented: $showExitConfirmation) {
      Button("取消", role: .cancel) {}
      Button("確定", role: .destructive) { dismiss() }
    } message: {
      Text("目前進度將不會儲存。")
    }
    .alert("需要授權", isPresented: $showPermissionAlert) {
      Button("前往設定") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("請在「設定 > 隱私權」中開啟麥克風與語音辨識的存取權限。")
    }
    // 監聽 SpeechService 的錯誤訊息，自動顯示 Alert
    .alert("語音功能錯誤", isPresented: Binding(
      get: { speech.errorMessage != nil },
      set: { if !$0 { speech.errorMessage = nil } }
    )) {
      Button("確定", role: .cancel) { speech.errorMessage = nil }
    } message: {
      Text(speech.errorMessage ?? "")
    }
    .onAppear {
      shuffledCards = cardsToUse.shuffled()
      sessionStartTime = Date()
    }
    .onDisappear {
      speech.stopSpeaking()
      speech.stopListening()
    }
  }

  // MARK: - 測驗主畫面

  private var quizInProgressView: some View {
    VStack {
      // 頂部工具列：退出 + TTS 音量 + 語音模式
      HStack {
        Button {
          if currentCardIndex > 0 || isFlipped {
            showExitConfirmation = true
          } else {
            dismiss()
          }
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
        }

        Spacer()

        // TTS 自動朗讀開關
        Button {
          ttsAutoSpeak.toggle()
          if ttsAutoSpeak { speech.stopListening(); isVoiceMode = false }
        } label: {
          Image(systemName: ttsAutoSpeak ? "speaker.wave.2.fill" : "speaker.slash")
            .font(.system(size: 18))
            .foregroundStyle(ttsAutoSpeak ? Color.accentColor : Color.secondary)
            .frame(width: 44, height: 44)
        }
        .help("自動朗讀答案")

        // 語音練習模式開關
        Button {
          toggleVoiceMode()
        } label: {
          Image(systemName: isVoiceMode ? "mic.fill" : "mic")
            .font(.system(size: 18))
            .foregroundStyle(isVoiceMode ? Color.accentColor : Color.secondary)
            .frame(width: 44, height: 44)
        }
        .help("語音練習模式")
      }
      .padding(.horizontal)
      .padding(.top, 8)

      // 進度文字
      if !shuffledCards.isEmpty {
        Text("Question \(currentCardIndex + 1) / \(shuffledCards.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.top)
      }

      Spacer()

      if shuffledCards.isEmpty {
        ContentUnavailableView(
          "沒有卡片",
          systemImage: "tray.fill",
          description: Text("請先新增知識卡片才能開始測驗"))
      } else if isVoiceMode {
        voicePracticeContent
      } else {
        normalFlipContent
      }

      Spacer()

      if !shuffledCards.isEmpty {
        if isVoiceMode {
          voiceBottomArea
        } else {
          normalBottomArea
        }
      }
    }
  }

  // MARK: - 一般翻卡模式

  private var normalFlipContent: some View {
    FlipCardView(
      card: shuffledCards[currentCardIndex],
      isFlipped: $isFlipped,
      onReveal: ttsAutoSpeak ? {
        let card = shuffledCards[currentCardIndex]
        speech.speakCard(front: card.title, back: card.content, language: language)
      } : nil
    )
    .frame(height: 400)
    .padding()
    .onTapGesture {
      withAnimation(.spring()) { isFlipped.toggle() }
    }
  }

  private var normalBottomArea: some View {
    Group {
      if isFlipped {
        HStack(spacing: 40) {
          Button(action: { nextCard(isCorrect: false) }) {
            VStack {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)
              Text("忘了")
                .font(.caption)
            }
          }
          Button(action: { nextCard(isCorrect: true) }) {
            VStack {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
              Text("記住了")
                .font(.caption)
            }
          }
        }
        .padding(.bottom, 50)
      } else {
        Text("點擊卡片查看答案")
          .foregroundStyle(.secondary)
          .padding(.bottom, 50)
      }
    }
  }

  // MARK: - 語音練習模式

  private var voicePracticeContent: some View {
    // 永遠只顯示正面（問題），不翻面
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

        Text(shuffledCards[currentCardIndex].title)
          .font(.title)
          .bold()
          .multilineTextAlignment(.center)
          .padding()

        Spacer()
      }
    }
    .frame(height: 400)
    .padding()
  }

  @ViewBuilder
  private var voiceBottomArea: some View {
    switch voiceState {
    case .idle:
      voiceIdleButton

    case .listening:
      voiceListeningArea

    case .matched:
      voiceMatchedView

    case .missed:
      voiceMissedView
    }
  }

  private var voiceIdleButton: some View {
    VStack(spacing: 8) {
      Button(action: startVoiceListening) {
        VStack(spacing: 6) {
          Image(systemName: "mic.circle.fill")
            .font(.system(size: 64))
            .foregroundStyle(.tint)
          Text("按下說出答案")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.bottom, 50)
  }

  private var voiceListeningArea: some View {
    VStack(spacing: 12) {
      // 動態脈衝指示器
      HStack(spacing: 4) {
        Image(systemName: "waveform")
          .font(.title2)
          .foregroundStyle(.red)
          .symbolEffect(.variableColor.iterative, isActive: speech.isListening)
        Text("聆聽中…")
          .font(.subheadline)
          .foregroundStyle(.red)
      }

      // 即時辨識文字
      if !speech.transcribedText.isEmpty {
        Text(speech.transcribedText)
          .font(.body)
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
          .lineLimit(3)
      }

      // 手動停止按鈕
      Button(action: {
        let result = speech.transcribedText
        speech.stopListening()
        handleVoiceResult(result)
      }) {
        Text("完成")
          .font(.headline)
          .foregroundStyle(.white)
          .padding(.horizontal, 32)
          .padding(.vertical, 10)
          .background(Color.red)
          .cornerRadius(20)
      }
    }
    .padding(.bottom, 50)
  }

  private var voiceMatchedView: some View {
    VStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 56))
        .foregroundStyle(.green)
      Text("答對了！")
        .font(.headline)
        .foregroundStyle(.green)
    }
    .padding(.bottom, 50)
    .onAppear {
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(1.2))
        voiceState = .idle
        nextCard(isCorrect: true)
      }
    }
  }

  private var voiceMissedView: some View {
    VStack(spacing: 12) {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 40))
        .foregroundStyle(.red)

      // 顯示正確答案讓使用者學習
      VStack(alignment: .leading, spacing: 4) {
        Text("正確答案")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(shuffledCards[currentCardIndex].content)
          .font(.body)
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)
          .lineLimit(4)
      }
      .padding()
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(12)
      .padding(.horizontal)

      HStack(spacing: 20) {
        Button(action: {
          speech.transcribedText = ""
          voiceState = .idle
        }) {
          Text("再試一次")
            .font(.subheadline)
            .foregroundStyle(.tint)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor, lineWidth: 1)
            )
        }

        Button(action: {
          speech.transcribedText = ""
          voiceState = .idle
          nextCard(isCorrect: false)
        }) {
          Text("跳過")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary, lineWidth: 1)
            )
        }
      }
    }
    .padding(.bottom, 30)
  }

  // MARK: - 語音邏輯

  private func toggleVoiceMode() {
    if isVoiceMode {
      speech.stopListening()
      isVoiceMode = false
      voiceState = .idle
      speech.transcribedText = ""
    } else {
      // 關閉 TTS 以避免音訊衝突
      ttsAutoSpeak = false
      isVoiceMode = true
      voiceState = .idle
    }
  }

  private func startVoiceListening() {
    Task {
      let granted = await speech.requestPermissions()
      guard granted else {
        showPermissionAlert = true
        return
      }
      voiceState = .listening
      speech.transcribedText = ""
      speech.onRecognitionFinished = { [self] finalText in
        handleVoiceResult(finalText)
      }
      do {
        try speech.startListening(language: language)
      } catch {
        voiceState = .idle
      }
    }
  }

  private func handleVoiceResult(_ recognized: String) {
    guard currentCardIndex < shuffledCards.count else { return }
    let expected = shuffledCards[currentCardIndex].content
    voiceState = speech.matches(recognized: recognized, expected: expected) ? .matched : .missed
  }

  // MARK: - 一般邏輯

  func saveStudyLog() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let total = shuffledCards.count
    let log = StudyLog(date: today, cardsReviewed: score, totalCards: total, activityType: "flashcards")
    modelContext.insert(log)
    try? modelContext.save()
  }

  func nextCard(isCorrect: Bool) {
    if isCorrect { score += 1 }
    withAnimation {
      if currentCardIndex < shuffledCards.count - 1 {
        isFlipped = false
        currentCardIndex += 1
        // 語音模式：朗讀下一張卡片的問題
        if isVoiceMode {
          speech.speak(shuffledCards[currentCardIndex].title, language: language)
        }
      } else {
        quizTimeSpent = Date().timeIntervalSince(sessionStartTime)
        showResult = true
      }
    }
  }

  func retryQuiz() {
    withAnimation {
      currentCardIndex = 0
      isFlipped = false
      showResult = false
      score = 0
      voiceState = .idle
      speech.transcribedText = ""
      shuffledCards = cardsToUse.shuffled()
    }
  }
}
