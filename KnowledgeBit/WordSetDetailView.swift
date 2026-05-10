// WordSetDetailView.swift
// 單字集詳情：顯示卡片清單、共編成員、開啟複習/選擇題/對戰。
// 業務邏輯位於 WordSetDetailViewModel；本檔僅負責 UI 呈現與導覽。

import SwiftUI
import SwiftData
import WidgetKit

struct WordSetDetailView: View {
  @Bindable var wordSet: WordSet
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var taskService: TaskService
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var questService: DailyQuestService
  @EnvironmentObject var authService: AuthService

  @StateObject private var vm = WordSetDetailViewModel()

  // UI 流程旗標（純 View 層）
  @State private var showingQuiz = false
  @State private var showingChoiceQuiz = false
  @State private var showingCollaboratorPicker = false
  @State private var showingCollaboratorList = false

  @State private var cachedSortedCards: [Card] = []

  /// 是否為此單字集的創辦人（依 Supabase word_sets.user_id 映射到本機 ownerUserId）
  private var isOwner: Bool {
    guard let currentId = authService.currentUserId else { return false }
    // 舊資料若尚未同步 ownerUserId，保守起見視為擁有者，避免擋住合法操作
    return wordSet.ownerUserId == nil || wordSet.ownerUserId == currentId
  }

  private var cards: [Card] {
    cachedSortedCards
  }

  private var otherCollaborators: [WordSetCollaborator] {
    vm.otherCollaborators(currentUserId: authService.currentUserId)
  }

  var body: some View {
    VStack(spacing: 0) {
      if cards.isEmpty {
        ContentUnavailableView(
          "尚無單字",
          systemImage: "tray.fill",
          description: Text("點擊右上角 + 新增單字到此單字集")
        )
        .padding()
      } else {
        List {
          ForEach(cards) { card in
            NavigationLink {
              CardDetailView(card: card)
            } label: {
              Text(card.title)
                .font(.headline)
            }
          }
          .onDelete { offsets in
            withAnimation {
              vm.deleteCards(at: offsets, in: cards, modelContext: modelContext, authService: authService)
            }
          }
        }
      }
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { toolbarContent }
    .safeAreaInset(edge: .bottom) { bottomBar }
    .fullScreenCover(isPresented: $showingQuiz) {
      QuizView(cards: cards, language: wordSet.language, wordSetId: wordSet.id, wordSetTitle: wordSet.title)
        .environmentObject(taskService)
        .environmentObject(experienceStore)
        .environmentObject(questService)
        .environmentObject(authService)
    }
    .fullScreenCover(isPresented: $showingChoiceQuiz) {
      choiceQuizCoverContent
        .environmentObject(taskService)
        .environmentObject(experienceStore)
        .environmentObject(questService)
        .environmentObject(authService)
    }
    .sheet(isPresented: $showingCollaboratorPicker) {
      CollaboratorPickerView(
        authService: authService,
        wordSetId: wordSet.id,
        initialSelectedIds: Set(vm.collaborators.map(\.userId))
      ) { updated in
        vm.setCollaborators(updated)
      }
    }
    .sheet(isPresented: $showingCollaboratorList) {
      CollaboratorListSheet(collaborators: vm.collaborators)
    }
    .task {
      // Cache the sorted list once on appear; avoid re-sorting on every render.
      cachedSortedCards = wordSet.cards.sorted { $0.createdAt > $1.createdAt }
      await vm.loadCollaborators(wordSetId: wordSet.id, authService: authService)
      await vm.pullCardsForWordSetIfNeeded(wordSet: wordSet, modelContext: modelContext, authService: authService)
      await vm.loadActiveBattleIfNeeded(wordSetId: wordSet.id, authService: authService)
    }
    .onChange(of: wordSet.cards.count) { _, _ in
      cachedSortedCards = wordSet.cards.sorted { $0.createdAt > $1.createdAt }
    }
    .handleAppError($vm.errorMessage)
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      HStack(spacing: 8) {
        Text(wordSet.title)
          .font(.headline.weight(.bold))
        if !otherCollaborators.isEmpty {
          collaboratorAvatarRow
        }
      }
    }
    ToolbarItemGroup(placement: .primaryAction) {
      // 只有創辦人可以管理共編與發起對戰，其餘共編者僅能編輯單字與參與已存在的戰鬥
      if isOwner {
        Button {
          Task {
            // 先將單字集同步到 Supabase，避免後端 create_word_set_invitation 回傳 "word_set not found"
            if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
              await sync.syncWordSet(wordSet)
            }
            await vm.loadCollaborators(wordSetId: wordSet.id, authService: authService)
            showingCollaboratorPicker = true
          }
        } label: {
          Image(systemName: "person.badge.plus")
        }
      }

      NavigationLink {
        AddCardView(wordSet: wordSet)
      } label: {
        Image(systemName: "plus")
      }

      NavigationLink {
        LectureImportView(wordSet: wordSet)
      } label: {
        Image(systemName: "doc.text.viewfinder")
      }
      .help("匯入 PDF 講義，產生摘要與測驗")

      Button {
        AppGroup.sharedUserDefaults()?.set(wordSet.id.uuidString, forKey: AppGroup.Keys.widgetWordSetId)
        WidgetReloader.reloadAll()
      } label: {
        Image(systemName: "rectangle.3.group")
      }
      .help("設為 Widget 單字集")
    }
  }

  // MARK: - Bottom Bar

  @ViewBuilder
  private var bottomBar: some View {
    if !cards.isEmpty {
      HStack(spacing: 10) {
        Button(action: { showingQuiz = true }) {
          bottomBarButtonLabel(systemImage: "play.fill", title: "開始複習")
        }
        .buttonStyle(.plain)
        .background(Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundColor(.white)

        Button(action: triggerChoiceQuiz) {
          bottomBarButtonLabel(systemImage: "list.bullet.rectangle.fill", title: "選擇題測驗")
        }
        .buttonStyle(.plain)
        .background(Color.orange.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundColor(.white)

        battleEntry
      }
      .padding()
      .background(Color(UIColor.systemGroupedBackground))
    }
  }

  @ViewBuilder
  private var battleEntry: some View {
    if let session = vm.activeBattleSession, session.isActive() {
      NavigationLink {
        BattleRoomView(
          roomId: session.roomId,
          wordSetID: session.wordSetID,
          wordSetTitle: wordSet.title,
          startDate: session.startDate,
          durationDays: session.durationDays,
          invitedMemberIDs: session.invitedMemberIDs,
          creatorId: session.creatorId
        )
      } label: {
        bottomBarButtonLabel(systemImage: "flag.2.crossed.fill", title: "對戰詳情")
      }
      .buttonStyle(.plain)
      .background(Color.purple.opacity(0.92))
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .foregroundColor(.white)
    } else if isOwner {
      NavigationLink {
        BattleInitiationView(wordSetID: wordSet.id, wordSetTitle: wordSet.title)
      } label: {
        bottomBarButtonLabel(systemImage: "person.2.fill", title: "發起對戰")
      }
      .buttonStyle(.plain)
      .background(Color.purple.opacity(0.92))
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .foregroundColor(.white)
    } else if vm.isLoadingBattleSession {
      bottomBarStatusLabel(systemImage: nil, title: "檢查戰鬥中…")
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundColor(.secondary)
    } else {
      bottomBarStatusLabel(systemImage: "hourglass", title: "等待對戰")
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .foregroundColor(.secondary)
    }
  }

  // MARK: - Choice Quiz Cover

  private func triggerChoiceQuiz() {
    showingChoiceQuiz = true
    vm.startChoiceQuiz(cards: cards, wordSet: wordSet, authService: authService)
  }

  @ViewBuilder
  private var choiceQuizCoverContent: some View {
    if vm.isGeneratingQuiz {
      generatingQuizView
    } else if let err = vm.quizGenerateError {
      quizErrorView(message: err)
    } else if let q = vm.generatedQuestions, !q.isEmpty {
      ChoiceQuizView(
        questions: q,
        onFinish: { score, total in
          vm.recordChoiceQuizResult(
            score: score,
            total: total,
            modelContext: modelContext,
            questService: questService,
            experienceStore: experienceStore
          )
          showingChoiceQuiz = false
          vm.resetChoiceQuizState()
        },
        wordSetId: wordSet.id,
        wordSetTitle: wordSet.title
      )
    } else if vm.generatedQuestions != nil {
      VStack(spacing: 16) {
        Text("未產生題目")
          .font(.headline)
        Button("關閉") {
          showingChoiceQuiz = false
          vm.resetChoiceQuizState()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var generatingQuizView: some View {
    NavigationStack {
      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.2)
        Text("正在產生題目…")
          .font(.headline)
          .foregroundStyle(.primary)
        Text("這會呼叫 AI 生成題目，可能需要 30～60 秒。")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 28)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemGroupedBackground))
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("取消") {
            vm.cancelChoiceQuizGeneration()
            showingChoiceQuiz = false
          }
        }
      }
    }
  }

  private func quizErrorView(message: String) -> some View {
    VStack(spacing: 20) {
      Text("無法產生題目")
        .font(.title2)
        .bold()
      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      if message.contains("timed out") || message.contains("逾時") {
        Text("可點「重試」再試一次（第二次通常較快）")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      HStack(spacing: 16) {
        Button("重試") {
          vm.startChoiceQuiz(cards: cards, wordSet: wordSet, authService: authService)
        }
        Button("關閉") {
          showingChoiceQuiz = false
          vm.resetChoiceQuizState()
        }
        .padding()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Bottom Bar Helpers

  private func bottomBarButtonLabel(systemImage: String, title: String) -> some View {
    VStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .semibold))
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .padding(.horizontal, 8)
  }

  private func bottomBarStatusLabel(systemImage: String?, title: String) -> some View {
    VStack(spacing: 6) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 16, weight: .semibold))
      } else {
        ProgressView()
          .controlSize(.small)
      }
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .padding(.horizontal, 8)
  }

  // MARK: - Collaborator Avatar Row

  private var collaboratorAvatarRow: some View {
    Button {
      showingCollaboratorList = true
    } label: {
      HStack(spacing: 8) {
        HStack(spacing: -10) {
          ForEach(Array(otherCollaborators.prefix(3).enumerated()), id: \.element.id) { index, collab in
            CollaboratorAvatarView(displayName: collab.displayName, avatarURL: collab.avatarURL, size: 28)
              .zIndex(Double(otherCollaborators.count - index))
          }
        }
        if otherCollaborators.count > 3 {
          Text("+\(otherCollaborators.count - 3)")
            .font(.caption.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(.systemBackground).opacity(0.9))
            .clipShape(Capsule())
        }
      }
      .padding(.horizontal)
      .padding(.top, 4)
    }
    .buttonStyle(.plain)
  }
}
