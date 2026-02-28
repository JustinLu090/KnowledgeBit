// WordSetDetailView.swift
// Detail view showing cards in a word set and quiz option

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
  @State private var showingQuiz = false
  @State private var showingChoiceQuiz = false
  @State private var generatedQuestions: [ChoiceQuestion]?
  @State private var quizGenerateError: String?
  @State private var isGeneratingQuiz = false
  @State private var showingCollaboratorPicker = false
  @State private var collaborators: [WordSetCollaborator] = []
  @State private var selectedCollaboratorIds: Set<UUID> = []
  @State private var showingCollaboratorList = false
  @State private var activeBattleSession: BattleSession? = nil
  @State private var isLoadingBattleSession = false

  /// 是否為此單字集的創辦人（依 Supabase word_sets.user_id 映射到本機 ownerUserId）
  private var isOwner: Bool {
    guard let currentId = authService.currentUserId else { return false }
    // 舊資料若尚未同步 ownerUserId，保守起見視為擁有者，避免擋住合法操作
    return wordSet.ownerUserId == nil || wordSet.ownerUserId == currentId
  }

  // Fetch cards for this word set
  private var cards: [Card] {
    wordSet.cards.sorted { $0.createdAt > $1.createdAt }
  }

  /// 此單字集內「除了自己」以外的成員（用於標題列頭像，不顯示自己的頭像）
  private var otherCollaborators: [WordSetCollaborator] {
    guard let currentId = authService.currentUserId else { return collaborators }
    return collaborators.filter { $0.userId != currentId }
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
            }             label: {
              Text(card.title)
                .font(.headline)
            }
          }
          .onDelete(perform: deleteCards)
        }
      }
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
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
              await loadCollaborators()
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

        Button {
          AppGroup.sharedUserDefaults()?.set(wordSet.id.uuidString, forKey: AppGroup.Keys.widgetWordSetId)
          WidgetReloader.reloadAll()
        } label: {
          Image(systemName: "rectangle.3.group")
        }
        .help("設為 Widget 單字集")
      }
    }
    .safeAreaInset(edge: .bottom) {
      Group {
        if !cards.isEmpty {
          VStack(spacing: 10) {
            Button(action: { showingQuiz = true }) {
              HStack {
                Image(systemName: "play.fill")
                Text("開始測驗")
                  .fontWeight(.bold)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(10)
            }
            Button(action: startChoiceQuiz) {
              HStack {
                Image(systemName: "list.bullet.rectangle.fill")
                Text("選擇題測驗")
                  .fontWeight(.semibold)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.orange.opacity(0.9))
              .foregroundColor(.white)
              .cornerRadius(10)
            }
            if let session = activeBattleSession, session.isActive() {
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
                HStack {
                  Image(systemName: "flag.2.crossed.fill")
                  Text("對戰詳情")
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
              }
              .buttonStyle(.plain)
            } else if isOwner {
              NavigationLink {
                BattleInitiationView(wordSetID: wordSet.id, wordSetTitle: wordSet.title)
              } label: {
                HStack {
                  Image(systemName: "person.2.fill")
                  Text("發起對戰")
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
              }
              .buttonStyle(.plain)
            } else if isLoadingBattleSession {
              HStack {
                ProgressView()
                Text("檢查戰鬥中…")
                  .fontWeight(.regular)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color(.systemGray5))
              .foregroundColor(.secondary)
              .cornerRadius(10)
            } else {
              HStack {
                Image(systemName: "hourglass")
                Text("等待創辦人發起對戰")
                  .fontWeight(.regular)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color(.systemGray5))
              .foregroundColor(.secondary)
              .cornerRadius(10)
            }
          }
          .padding()
          .background(Color(UIColor.systemGroupedBackground))
        }
      }
    }
    .fullScreenCover(isPresented: $showingQuiz) {
      QuizView(cards: cards)
        .environmentObject(taskService)
        .environmentObject(experienceStore)
        .environmentObject(questService)
    }
    .fullScreenCover(isPresented: $showingChoiceQuiz) {
      choiceQuizCoverContent
        .environmentObject(taskService)
        .environmentObject(experienceStore)
        .environmentObject(questService)
    }
    .sheet(isPresented: $showingCollaboratorPicker) {
      CollaboratorPickerView(
        authService: authService,
        wordSetId: wordSet.id,
        initialSelectedIds: Set(collaborators.map(\.userId))
      ) { updated in
        collaborators = updated
      }
    }
    .sheet(isPresented: $showingCollaboratorList) {
      CollaboratorListSheet(collaborators: collaborators)
    }
    .task {
      await loadCollaborators()
      await pullCardsForWordSetIfNeeded()
      await loadActiveBattleIfNeeded()
    }
  }

  /// 從 Supabase 拉取此單字集的卡片（共編時可看到對方新增的單字卡）
  private func pullCardsForWordSetIfNeeded() async {
    guard let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) else { return }
    await sync.pullCardsForWordSet(wordSet: wordSet, modelContext: modelContext)
  }

  private func loadCollaborators() async {
    guard let currentUserId = authService.currentUserId else { return }
    let service = WordSetCollaboratorService(authService: authService, userId: currentUserId)
    do {
      collaborators = try await service.fetchCollaborators(wordSetId: wordSet.id)
    } catch {
      print("⚠️ [WordSet] fetchCollaborators 失敗: \(error)")
    }
  }

  /// 載入此單字集是否有進行中的對戰（創辦人與共編者都會用到，用來顯示「對戰詳情」或「發起對戰」）
  private func loadActiveBattleIfNeeded() async {
    guard let currentUserId = authService.currentUserId else { return }
    isLoadingBattleSession = true
    defer { isLoadingBattleSession = false }

    let service = BattleRoomService(authService: authService, userId: currentUserId)
    do {
      if let session = try await service.fetchActiveRoom(wordSetID: wordSet.id) {
        await MainActor.run {
          activeBattleSession = session
        }
      }
    } catch {
      // 使用者快速離開畫面時 task 會被取消，屬於預期行為，不當作失敗
      let ns = error as NSError
      if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
      print("⚠️ [WordSet] loadActiveBattleIfNeeded 失敗: \(error)")
    }
  }

  private func startChoiceQuiz() {
    showingChoiceQuiz = true
    isGeneratingQuiz = true
    quizGenerateError = nil
    generatedQuestions = nil
    Task {
      do {
        let q = try await AIService(client: authService.getClient()).generateQuizQuestions(cards: cards, targetLanguage: wordSet.title)
        await MainActor.run {
          generatedQuestions = q
          isGeneratingQuiz = false
        }
      } catch {
        await MainActor.run {
          quizGenerateError = error.localizedDescription
          isGeneratingQuiz = false
        }
      }
    }
  }

  @ViewBuilder
  private var choiceQuizCoverContent: some View {
    if isGeneratingQuiz {
      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.2)
        Text("正在產生題目…")
          .font(.headline)
          .foregroundStyle(.secondary)
        Text("可能需要 30～60 秒，請稍候")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let err = quizGenerateError {
      VStack(spacing: 20) {
        Text("無法產生題目")
          .font(.title2)
          .bold()
        Text(err)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
        if err.contains("timed out") || err.contains("逾時") {
          Text("可點「重試」再試一次（第二次通常較快）")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        HStack(spacing: 16) {
          Button("重試") {
            quizGenerateError = nil
            startChoiceQuiz()
          }
          Button("關閉") {
            showingChoiceQuiz = false
            quizGenerateError = nil
          }
          .padding()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let q = generatedQuestions, !q.isEmpty {
      ChoiceQuizView(questions: q) { score, total in
        recordChoiceQuizResult(score: score, total: total)
        showingChoiceQuiz = false
        generatedQuestions = nil
      }
    } else if generatedQuestions != nil {
      VStack(spacing: 16) {
        Text("未產生題目")
          .font(.headline)
        Button("關閉") {
          showingChoiceQuiz = false
          generatedQuestions = nil
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func recordChoiceQuizResult(score: Int, total: Int) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let log = StudyLog(date: today, cardsReviewed: score, totalCards: total)
    modelContext.insert(log)
    try? modelContext.save()
    questService.recordWordSetCompleted(experienceStore: experienceStore)
    let accuracy = total > 0 ? Int(Double(score) / Double(total) * 100) : 0
    questService.recordWordSetQuizResult(accuracyPercent: accuracy, isPerfect: (total > 0 && score == total), quizType: .multipleChoice, experienceStore: experienceStore)
  }
  
  private func deleteCards(offsets: IndexSet) {
    let idsToDelete = offsets.map { cards[$0].id }
    withAnimation {
      for index in offsets {
        modelContext.delete(cards[index])
      }
      do {
        try modelContext.save()
        WidgetReloader.reloadAll()
        if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
          Task {
            for id in idsToDelete {
              await sync.deleteCard(id: id)
            }
          }
        }
      } catch {
        print("❌ Failed to delete card: \(error.localizedDescription)")
      }
    }
  }
}

// MARK: - 共編成員挑選

private struct CollaboratorPickerView: View {
  @Environment(\.dismiss) private var dismiss
  let authService: AuthService
  let wordSetId: UUID
  let initialSelectedIds: Set<UUID>
  let onUpdated: ([WordSetCollaborator]) -> Void
  @StateObject private var communityViewModel = CommunityViewModel()
  @State private var localSelection: Set<UUID> = []
  /// 已經邀請過我的使用者 ID（pending），這些人應顯示為「已加入」且不可再邀請
  @State private var pendingInviterIds: Set<UUID> = []
  /// 發送邀請後若有失敗，顯示錯誤訊息
  @State private var sendInvitationErrorMessage: String?
  /// 最後一筆發送失敗的後端訊息（用於顯示 word_set not found 等提示）
  @State private var lastSendInvitationError: String?

  var body: some View {
    NavigationStack {
      List {
        if communityViewModel.isLoading {
          HStack {
            ProgressView()
            Text("載入好友中…")
              .foregroundStyle(.secondary)
          }
        } else if let error = communityViewModel.errorMessage {
          VStack(alignment: .leading, spacing: 8) {
            Text("載入失敗")
              .font(.headline)
            Text(error)
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Button("重試") {
              Task { await communityViewModel.loadFriends(authService: authService) }
            }
            .buttonStyle(.bordered)
          }
        } else if communityViewModel.friends.isEmpty {
          Text("目前尚無好友可邀請。")
            .foregroundStyle(.secondary)
        } else {
          Section {
            Text("選擇要邀請的好友，對方會在「社群」收到邀請並可選擇接受或拒絕。")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Section("好友") {
            ForEach(communityViewModel.friends) { friend in
              let isAlreadyCollaborator = initialSelectedIds.contains(friend.userId) || pendingInviterIds.contains(friend.userId)
              Button {
                if !isAlreadyCollaborator { toggleSelection(friend.userId) }
              }               label: {
                HStack(spacing: 12) {
                  CollaboratorAvatarView(displayName: friend.displayName, avatarURL: friend.avatarURL, size: 44)
                  VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                      Text(friend.displayName)
                        .font(.body)
                      if isAlreadyCollaborator {
                        Text("已加入")
                          .font(.caption2)
                          .foregroundStyle(.white)
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(Color.green)
                          .cornerRadius(6)
                      }
                    }
                    Text("Lv \(friend.level)")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  if isAlreadyCollaborator {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundStyle(.green)
                  } else if localSelection.contains(friend.userId) {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundStyle(.blue)
                  } else {
                    Image(systemName: "circle")
                      .foregroundStyle(.tertiary)
                  }
                }
              }
              .buttonStyle(.plain)
              .disabled(isAlreadyCollaborator)
            }
          }
        }
      }
      .navigationTitle("邀請共編成員")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("邀請") {
            Task {
              await sendInvitations()
            }
          }
          .disabled(localSelection.isEmpty)
        }
      }
      .task {
        await communityViewModel.loadFriends(authService: authService)
        localSelection = initialSelectedIds
        if let currentUserId = authService.currentUserId {
          let invitationService = WordSetInvitationService(authService: authService, userId: currentUserId)
          let myPending = (try? await invitationService.fetchMyPendingInvitations()) ?? []
          pendingInviterIds = Set(myPending.filter { $0.wordSetId == wordSetId }.map(\.inviterId))
        }
      }
      .alert("發送邀請失敗", isPresented: Binding(
        get: { sendInvitationErrorMessage != nil },
        set: { if !$0 { sendInvitationErrorMessage = nil } }
      )) {
        Button("確定", role: .cancel) { sendInvitationErrorMessage = nil }
      } message: {
        if let msg = sendInvitationErrorMessage {
          Text(msg)
        }
      }
    }
  }

  private func toggleSelection(_ id: UUID) {
    if localSelection.contains(id) {
      localSelection.remove(id)
    } else {
      localSelection.insert(id)
    }
  }

  /// 發送邀請給選取的好友（對方需在社群接受後才會加入共編）
  private func sendInvitations() async {
    guard let currentUserId = authService.currentUserId else {
      print("⚠️ [WordSet] sendInvitations 跳過：無 currentUserId")
      return
    }
    let invitationService = WordSetInvitationService(authService: authService, userId: currentUserId)
    // 不重複邀請已是共編者或已邀請過我的人
    let toInvite = localSelection.filter { !initialSelectedIds.contains($0) && !pendingInviterIds.contains($0) }
    print("[WordSet] 邀請共編：wordSetId=\(wordSetId), 將發送給 \(toInvite.count) 人, targetUserIds=\(toInvite.map(\.uuidString))")
    var successCount = 0
    var failureCount = 0
    for inviteeId in toInvite {
      do {
        try await invitationService.sendInvitation(wordSetId: wordSetId, inviteeId: inviteeId)
        successCount += 1
        print("✅ [WordSet] sendInvitation Success: inviteeId=\(inviteeId)")
      } catch {
        failureCount += 1
        let errMsg = String(describing: error)
        print("❌ [WordSet] sendInvitation Error: inviteeId=\(inviteeId), error=\(error)")
        lastSendInvitationError = errMsg
      }
    }
    print("[WordSet] 邀請結果：Success=\(successCount), Error=\(failureCount)")
    await MainActor.run {
      if failureCount > 0 {
        let hint = (lastSendInvitationError?.contains("word_set not found") == true)
          ? "（此單字集尚未同步至伺服器，請確認網路連線後重試。）"
          : ""
        sendInvitationErrorMessage = "有 \(failureCount) 筆邀請發送失敗，請稍後再試。\(hint)"
      } else {
        dismiss()
      }
    }
  }
}

// MARK: - 共編成員 Avatar Row & List

extension WordSetDetailView {
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

private struct CollaboratorAvatarView: View {
  let displayName: String
  var avatarURL: String?
  var size: CGFloat = 28

  private var initials: String {
    String(displayName.prefix(1))
  }

  var body: some View {
    Group {
      if let url = avatarURL, !url.isEmpty {
        AvatarView(avatarURL: url, size: size)
          .clipShape(Circle())
      } else {
        ZStack {
          Circle()
            .fill(Color.blue.opacity(0.85))
          Text(initials)
            .font(size > 32 ? .body.bold() : .caption.bold())
            .foregroundStyle(.white)
        }
      }
    }
    .frame(width: size, height: size)
    .overlay(
      Circle()
        .stroke(Color(.systemBackground), lineWidth: 2)
    )
  }
}

private struct CollaboratorListSheet: View {
  @Environment(\.dismiss) private var dismiss
  let collaborators: [WordSetCollaborator]

  var body: some View {
    NavigationStack {
      List {
        if collaborators.isEmpty {
          Text("目前尚無共編成員")
            .foregroundStyle(.secondary)
        } else {
          ForEach(collaborators) { c in
            HStack(spacing: 12) {
              CollaboratorAvatarView(displayName: c.displayName, avatarURL: c.avatarURL, size: 44)
              Text(c.displayName)
                .font(.body)
              Spacer()
            }
          }
        }
      }
      .navigationTitle("共編成員")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("關閉") { dismiss() }
        }
      }
    }
  }
}


