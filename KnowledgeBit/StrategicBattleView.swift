// StrategicBattleView.swift
// 4×4 戰略地圖主畫面：協調生命週期（loadInitialBoard、Realtime 訂閱、Widget 同步）
// 並組合各子畫面（Header / Grid / RoundSummary / ControlPanel）。
// UI 子組件位於：
//   * BattleStatusHeaderView.swift
//   * BattleGridView.swift
//   * BattleRoundSummaryView.swift
//   * BattleControlPanelView.swift

import SwiftUI

struct StrategicBattleView: View {
  let roomId: UUID
  let wordSetID: UUID
  /// 創辦人 = 藍隊；被邀請 = 紅隊。nil 時視為己方藍隊。
  let creatorId: UUID?
  /// 單字集標題，供 Widget 對戰地圖快照顯示用。
  let wordSetTitle: String?
  @EnvironmentObject private var authService: AuthService
  @EnvironmentObject private var energyStore: BattleEnergyStore

  init(roomId: UUID, wordSetID: UUID, creatorId: UUID? = nil, wordSetTitle: String? = nil) {
    self.roomId = roomId
    self.wordSetID = wordSetID
    self.creatorId = creatorId
    self.wordSetTitle = wordSetTitle
  }

  var body: some View {
    let namespace = wordSetID.uuidString
    StrategicBattleViewContent(
      roomId: roomId,
      wordSetID: wordSetID,
      wordSetTitle: wordSetTitle,
      authService: authService,
      initialKE: energyStore.availableKE(for: namespace),
      creatorId: creatorId,
      namespace: namespace,
      onConsumeKE: { amount in
        _ = energyStore.spendKE(amount, namespace: namespace)
      }
    )
  }
}

private struct StrategicBattleViewContent: View {
  let roomId: UUID
  let wordSetID: UUID
  let wordSetTitle: String?
  let authService: AuthService
  let initialKE: Int
  let creatorId: UUID?
  let namespace: String
  let onConsumeKE: (Int) -> Void
  @StateObject private var vm: StrategicBattleViewModel

  /// 地圖最大邊長（放大地圖時可提高）
  private let gridMaxSide: CGFloat = 480
  /// 左右留白縮小，讓地圖貼齊兩側
  private let gridPadding: CGFloat = 8

  private let neutralColor: Color = Color.black.opacity(0.35)

  /// 己方隊伍顏色（創辦人=藍、被邀請=紅）
  private var playerTeamColor: Color {
    isRedTeam ? .red : .blue
  }

  /// 對方隊伍顏色
  private var enemyTeamColor: Color {
    isRedTeam ? .blue : .red
  }

  private var isRedTeam: Bool {
    guard let cid = creatorId, let me = authService.currentUserId else { return false }
    return me != cid
  }

  init(
    roomId: UUID,
    wordSetID: UUID,
    wordSetTitle: String?,
    authService: AuthService,
    initialKE: Int,
    creatorId: UUID? = nil,
    namespace: String,
    onConsumeKE: @escaping (Int) -> Void
  ) {
    self.roomId = roomId
    self.wordSetID = wordSetID
    self.wordSetTitle = wordSetTitle
    self.authService = authService
    self.initialKE = initialKE
    self.creatorId = creatorId
    self.namespace = namespace
    self.onConsumeKE = onConsumeKE
    let bucketSeconds = 3600
    _vm = StateObject(
      wrappedValue: StrategicBattleViewModel(
        roomId: roomId,
        authService: authService,
        creatorId: creatorId,
        initialKE: initialKE,
        settlementBucketSeconds: bucketSeconds,
        onConsumedKE: onConsumeKE
      )
    )
  }

  var body: some View {
    content
      .onAppear { Task { await vm.loadInitialBoard() } }
      .onDisappear { vm.unsubscribeFromRealtime() }
      .task {
        // Subscribes to Realtime when the view appears; SwiftUI cancels this task
        // automatically when the view disappears, triggering the defer/unsubscribe in the VM.
        await vm.subscribeToRealtime()
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
        // Realtime reconnects automatically on foreground, but won't replay missed events.
        // Trigger a one-shot reload to catch up; skip if Realtime is not yet active (VM will
        // refresh via loadInitialBoard once the subscription is re-established).
        guard vm.isRealtimeActive else { return }
        Task { await vm.loadInitialBoard() }
      }
      .onChange(of: vm.cells) { _, newCells in
        if newCells.count == 16, let me = authService.currentUserId {
          let snapshots = newCells.map { cell in
            WidgetBattleCellSnapshot(
              id: cell.id,
              owner: cell.owner.rawValue,
              hp_now: cell.hpNow,
              hp_max: cell.hpMax
            )
          }
          WidgetBattleSnapshot.save(
            roomId: roomId,
            wordSetId: wordSetID,
            wordSetTitle: wordSetTitle,
            creatorId: creatorId,
            currentUserId: me,
            cells: snapshots
          )
        }
      }
      .alert("格子上限 400", isPresented: Binding(
        get: { vm.cellCapAlertMessage != nil },
        set: { if !$0 { vm.cellCapAlertMessage = nil } }
      )) {
        Button("確定", role: .cancel) { vm.cellCapAlertMessage = nil }
      } message: {
        Text(vm.cellCapAlertMessage ?? "")
      }
      .handleAppError($vm.errorMessage)
  }

  private var content: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(spacing: 14) {
        // 頂部狀態區，放在安全區域內，避免被瀏海或導航列擋住
        BattleStatusHeaderView(
          vm: vm,
          playerTeamColor: playerTeamColor,
          isRedTeam: isRedTeam
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)

        BattleGridView(
          vm: vm,
          playerTeamColor: playerTeamColor,
          enemyTeamColor: enemyTeamColor,
          neutralColor: neutralColor,
          gridMaxSide: gridMaxSide
        )
        .padding(.horizontal, gridPadding)

        // 上一輪統整：固定顯示在地圖與底部操作區之間，不隨選格切換消失
        if let summary = vm.lastRoundSummary {
          BattleRoundSummaryView(summary: summary)
            .padding(.horizontal, 12)
        }

        BattleControlPanelView(
          vm: vm,
          playerTeamColor: playerTeamColor,
          enemyTeamColor: enemyTeamColor
        )
        .padding(.top, 8)
      }
      .padding(.bottom, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .navigationTitle("對戰")
    .navigationBarTitleDisplayMode(.inline)
    .overlay(lockOverlay)
  }

  // MARK: - Lock overlay

  @ViewBuilder
  private var lockOverlay: some View {
    if vm.isSettlementLocked {
      VStack(spacing: 10) {
        Text("結算中…")
          .font(.system(size: 18, weight: .bold, design: .rounded))
        Text("整點前最後 2 分鐘已鎖定，禁止新的積分分配。")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.white.opacity(0.12), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 10)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black.opacity(0.12))
      .transition(.opacity)
    }
  }
}
