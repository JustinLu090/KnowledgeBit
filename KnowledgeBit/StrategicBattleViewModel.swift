// StrategicBattleViewModel.swift
// 4×4 戰略地圖 ViewModel：協調棋盤狀態、KE 分配、定時結算。
// 子職責拆分：
//   * BattleRealtimeSubscriber — Supabase Realtime 訂閱
//   * FailedSubmissionQueue   — 失敗 bucket 重試佇列 + 持久化
//   * BattleSettlementEngine  — 純 local 結算運算

import Foundation
import SwiftUI
import Combine
import os

@MainActor
final class StrategicBattleViewModel: ObservableObject {
  enum Owner: String, Codable {
    case neutral
    case player
    case enemy
  }

  struct Cell: Identifiable, Equatable {
    let id: Int // 0...15
    var owner: Owner
    var hpNow: Int
    var hpMax: Int
    var decayPerHour: Int

    // For UI effects
    var enemyPressure: Int // enemy KE投入（用來觸發 UnderAttack 視覺）
  }

  // MARK: - Published state

  @Published private(set) var cells: [Cell] = []
  @Published var selectedCellID: Int? = nil

  /// 玩家本小時暫存（未結算）分配：cellID -> KE
  @Published private(set) var pendingKE: [Int: Int] = [:]

  /// 本小時玩家可用積分（KE）總額
  @Published private(set) var hourlyBudget: Int

  /// 距整點結算秒數
  @Published private(set) var secondsToTopOfHour: Int = 0

  /// 整點前最後 2 分鐘鎖定
  @Published private(set) var isSettlementLocked: Bool = false

  /// 顯示「格子上限 400」提示（設為非 nil 時彈出，關閉後請清空）
  @Published var cellCapAlertMessage: String? = nil

  /// 過渡型錯誤訊息（雲端結算失敗、初始載入失敗等），由 .handleAppError 顯示頂部 banner。
  @Published var errorMessage: String? = nil

  /// 上一輪結算的雙方動作統整（結算後或進入畫面時填入，供 UI 顯示）
  @Published private(set) var lastRoundSummary: BattleRoundSummary? = nil
  /// 上一輪對應的 bucket 起始時間（供 UI 顯示「上一輪 09:00–10:00」）
  @Published private(set) var lastRoundBucket: Date? = nil

  // MARK: - Collaborators

  /// 失敗提交佇列（僅在有 roomId 時建立；本地模式為 nil）
  private let failedQueue: FailedSubmissionQueue?
  /// Realtime 訂閱（僅在有 roomId + auth 時建立；本地模式為 nil）
  private let realtimeSubscriber: BattleRealtimeSubscriber?

  /// view 可據此決定是否跳過手動 foreground polling。
  var isRealtimeActive: Bool { realtimeSubscriber?.isActive ?? false }

  private var timerCancellable: AnyCancellable?
  private var nowProvider: () -> Date
  private let roomId: UUID?
  private let authService: AuthService?
  private let creatorId: UUID?
  private let pendingStore = BattlePendingStore()
  /// 每個結算週期可以使用的基礎 KE 上限（由 initialKE 決定，例如 400）
  private let baseHourlyBudget: Int
  private let settlementBucketSeconds: Int
  private var lastBucketStart: Date
  private let onConsumedKE: ((Int) -> Void)?

  private var battleRoomService: BattleRoomService? {
    guard let auth = authService, let uid = auth.currentUserId else { return nil }
    return BattleRoomService(authService: auth, userId: uid)
  }

  private func currentHourBucket() -> Date {
    let now = nowProvider()
    let cal = Calendar.current
    var comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
    comps.minute = 0
    comps.second = 0
    return cal.date(from: comps) ?? now
  }

  /// 依 settlementBucketSeconds 取得目前 bucket 起始時間
  private func currentBucket() -> Date {
    if settlementBucketSeconds == BattleConstants.defaultBucketSeconds { return currentHourBucket() }
    let now = nowProvider()
    let bucket = floor(now.timeIntervalSince1970 / Double(settlementBucketSeconds)) * Double(settlementBucketSeconds)
    return Date(timeIntervalSince1970: bucket)
  }

  private var lockoutSeconds: Int {
    // 正式：整點前 2 分鐘鎖定；測試縮短 bucket 時避免永遠鎖住
    if settlementBucketSeconds >= BattleConstants.defaultBucketSeconds {
      return BattleConstants.hourlyLockoutSeconds
    }
    return BattleConstants.shortBucketLockoutSeconds
  }

  // MARK: - Init

  init(
    roomId: UUID? = nil,
    authService: AuthService? = nil,
    creatorId: UUID? = nil,
    initialKE: Int = BattleConstants.defaultInitialKE,
    settlementBucketSeconds: Int = BattleConstants.defaultBucketSeconds,
    onConsumedKE: ((Int) -> Void)? = nil,
    nowProvider: @escaping () -> Date = { Date() }
  ) {
    self.roomId = roomId
    self.authService = authService
    self.creatorId = creatorId
    let clampedInitial = max(0, initialKE)
    self.hourlyBudget = clampedInitial
    self.baseHourlyBudget = clampedInitial
    self.settlementBucketSeconds = max(BattleConstants.minBucketSeconds, settlementBucketSeconds)
    self.nowProvider = nowProvider
    self.lastBucketStart = Date.distantPast
    self.onConsumedKE = onConsumedKE

    if let rid = roomId {
      self.failedQueue = FailedSubmissionQueue(roomId: rid)
      if let auth = authService {
        self.realtimeSubscriber = BattleRealtimeSubscriber(roomId: rid, authService: auth)
      } else {
        self.realtimeSubscriber = nil
      }
    } else {
      self.failedQueue = nil
      self.realtimeSubscriber = nil
    }

    self.bootstrapInitialBoard()
    self.startTimer()
    self.refreshCountdown()
    self.lastBucketStart = self.currentBucket()
  }

  /// Load board from cloud when roomId and auth are set; otherwise no-op.
  /// 同時還原本小時已暫存的 KE 分配（上次離開前的操作），可繼續修改直到整點前 2 分鐘鎖定。
  func loadInitialBoard() async {
    guard let rid = roomId, let service = battleRoomService else { return }
    let bucket = currentBucket()
    do {
      #if DEBUG
      AppLog.battle.info("[Battle] loadInitialBoard bucket=\(bucket) bucketSeconds=\(self.settlementBucketSeconds)")
      #endif
      let dtos = try await service.fetchBoardState(roomId: rid, hourBucket: bucket, bucketSeconds: settlementBucketSeconds)
      if dtos.count == BattleConstants.totalCells {
        // 依 id 排序，確保 cells[i] 對應格子 i（左上 id=0 → #1 紅隊出發，右下 id=15 → #16 藍隊出發）
        let sorted = dtos.sorted(by: { $0.id < $1.id })
        cells = sorted.map(Self.makeCell(from:))
      }
      // 還原本小時已暫存的 KE 分配，下次點開仍可看到並修改
      if let loaded = pendingStore.load(roomId: rid, hourBucket: bucket), !loaded.isEmpty {
        pendingKE = loaded
        #if DEBUG
        AppLog.battle.info("[Battle] restore pendingKE from store: \(String(describing: loaded), privacy: .public)")
        #endif
      }
      // 還原跨 session 持久化的失敗提交佇列
      failedQueue?.restore()
      // 載入上一輪的雙方動作統整，一進畫面就顯示（含雙方皆未投入時）
      let prevBucket = Date(timeIntervalSince1970: bucket.timeIntervalSince1970 - Double(settlementBucketSeconds))
      if let summary = try? await service.fetchRoundSummary(roomId: rid, hourBucket: prevBucket, bucketSeconds: settlementBucketSeconds) {
        lastRoundSummary = summary
        lastRoundBucket = prevBucket
        // 若後端剛寫入資料可能尚未可見，空結果時延遲再試一次
        if summary.blueAllocations.isEmpty && summary.redAllocations.isEmpty {
          try? await Task.sleep(nanoseconds: 1_500_000_000)
          if let retry = try? await service.fetchRoundSummary(roomId: rid, hourBucket: prevBucket, bucketSeconds: settlementBucketSeconds),
             !retry.blueAllocations.isEmpty || !retry.redAllocations.isEmpty {
            lastRoundSummary = retry
          }
        }
      }
    } catch {
      #if DEBUG
      AppLog.battle.info("[Battle] loadInitialBoard error: \(error.localizedDescription, privacy: .public)")
      #endif
      // 棋盤保留 bootstrap 狀態，同時透過 banner 通知使用者載入失敗。
      errorMessage = AppError.networkError(error).errorDescription
    }
  }

  // MARK: - Realtime Subscription (delegated)

  /// 訂閱 battle_cells Realtime 變更；會阻塞直到 view 取消（透過 SwiftUI .task 生命週期）。
  func subscribeToRealtime() async {
    guard let subscriber = realtimeSubscriber else { return }
    await subscriber.subscribe { [weak self] in
      await self?.refreshBoardFromRealtime()
    }
  }

  /// view onDisappear 時呼叫，確保 channel 立即釋放。
  func unsubscribeFromRealtime() {
    realtimeSubscriber?.unsubscribe()
  }

  /// Realtime 事件觸發時的輕量盤面刷新：只重取 cells，不重置 pendingKE 或 round summary
  private func refreshBoardFromRealtime() async {
    guard let rid = roomId, let service = battleRoomService else { return }
    let bucket = currentBucket()
    guard let dtos = try? await service.fetchBoardState(
      roomId: rid, hourBucket: bucket, bucketSeconds: settlementBucketSeconds
    ), dtos.count == BattleConstants.totalCells else { return }

    let sorted = dtos.sorted { $0.id < $1.id }
    cells = sorted.map(Self.makeCell(from:))
  }

  deinit {
    timerCancellable?.cancel()
    // unsubscribeFromRealtime() cannot be called directly from deinit (MainActor isolation).
    // The channel is released when the Task spawned by the view's .task modifier is cancelled
    // (via SwiftUI's automatic task lifecycle), which triggers the defer in the subscriber.
  }

  // MARK: - Derived

  var remainingKE: Int {
    max(0, hourlyBudget - pendingKE.values.reduce(0, +))
  }

  var occupiedCount: Int {
    cells.filter { $0.owner == .player }.count
  }

  /// 對方佔領格數（供 UI 顯示「藍隊 X 格、紅隊 Y 格」讓雙方看到一致數字）
  var enemyOccupiedCount: Int {
    cells.filter { $0.owner == .enemy }.count
  }

  var totalInvestedThisHour: Int {
    pendingKE.values.reduce(0, +)
  }

  // MARK: - Public API

  func cell(for id: Int) -> Cell {
    cells[id]
  }

  func setSelected(cellID: Int?) {
    guard !isSettlementLocked else { return }
    selectedCellID = cellID
  }

  // MARK: - Reachability

  /// 可進攻：與己方領地相鄰（若玩家被全滅/領地為0，外環全部可進攻）
  func isAttackableTarget(_ id: Int) -> Bool {
    let c = cells[id]
    if c.owner == .player { return false }
    if occupiedCount == 0 { return BattleBoard.isEdgeCell(id) }   // 全滅後重新開局：外環可進攻
    return BattleBoard.neighbors(of: id).contains(where: { cells[$0].owner == .player })
  }

  /// 不可觸及：非己方且不可進攻
  func isLockedCell(_ id: Int) -> Bool {
    let c = cells[id]
    if c.owner == .player { return false }
    return !isAttackableTarget(id)
  }

  func isUnderAttack(_ id: Int) -> Bool {
    cells[id].enemyPressure > 0
  }

  func pendingValue(for id: Int) -> Int {
    pendingKE[id, default: 0]
  }

  /// 該格本輪最多可投入的 KE：己方格子為「不超過 hpMax - hpNow」，進攻則不超過 BattleConstants.perCellKECap
  func maxAllowedKE(for id: Int) -> Int {
    let c = cells[id]
    if c.owner == .player {
      return max(0, min(BattleConstants.perCellKECap, c.hpMax - c.hpNow))
    }
    return BattleConstants.perCellKECap
  }

  /// 更新選取格子的投入 KE（會自動 clamp 到剩餘可用，且不超過格子上限；加固時不讓 HP 超過 400）
  func updatePendingKE(for id: Int, to newValue: Int) {
    guard !isSettlementLocked else { return }
    let clamped = max(0, newValue)

    let othersSum = pendingKE
      .filter { $0.key != id }
      .map { $0.value }
      .reduce(0, +)

    let maxByBudget = max(0, hourlyBudget - othersSum)
    let maxForCell = maxAllowedKE(for: id)
    let finalValue = min(clamped, maxByBudget, maxForCell)

    if clamped > maxForCell, maxForCell < BattleConstants.perCellKECap {
      cellCapAlertMessage = "格子上限 \(BattleConstants.perCellKECap)，此格目前 HP 已達 \(cells[id].hpNow)/\(cells[id].hpMax)，最多只能再投入 \(maxForCell) KE。"
    }

    if finalValue == 0 {
      pendingKE.removeValue(forKey: id)
    } else {
      pendingKE[id] = finalValue
    }
    persistPendingIfNeeded()
  }

  /// 將本小時 KE 分配寫入本地，離開再進入仍可看到並修改
  private func persistPendingIfNeeded() {
    guard let rid = roomId else { return }
    pendingStore.save(roomId: rid, hourBucket: currentBucket(), allocations: pendingKE)
  }

  /// 依企劃：HP_next = HP_now + KE_in − KE_out − Decay
  func predictedHPNext(for id: Int) -> Int {
    let c = cells[id]
    let keIn = (c.owner == .player) ? pendingValue(for: id) : 0
    let keOut = c.enemyPressure
    let next = c.hpNow + keIn - keOut - c.decayPerHour
    return max(0, min(c.hpMax, next))
  }

  // MARK: - Settlement

  func settleHour() {
    #if DEBUG
    AppLog.battle.info("[Battle] settleHour() called; pendingKE=\(String(describing: self.pendingKE), privacy: .public) remainingKE=\(self.remainingKE)")
    #endif
    if let rid = roomId, let service = battleRoomService, let queue = failedQueue {
      settleHourWithCloud(roomId: rid, service: service, queue: queue)
      return
    }
    settleHourLocal()
  }

  private func settleHourWithCloud(roomId rid: UUID, service: BattleRoomService, queue: FailedSubmissionQueue) {
    let newHourBucket = currentBucket()
    let previousHourBucket = Date(timeIntervalSince1970: newHourBucket.timeIntervalSince1970 - Double(settlementBucketSeconds))

    // ① Guard: prevent double-settlement for the same bucket (timer double-fire protection)
    guard queue.tryBeginFlight(bucket: previousHourBucket) else {
      #if DEBUG
      AppLog.battle.info("[Battle] bucket \(previousHourBucket) already in flight, skipping double-settlement")
      #endif
      return
    }

    // ② Snapshot current allocations NOW, before any async suspension point.
    //    The retry path must use THIS snapshot, not whatever pendingKE contains later.
    let currentAllocations = pendingKE
    let currentSpend = currentAllocations.values.reduce(0, +)
    let beforeCells = cells

    #if DEBUG
    AppLog.battle.info("[Battle] settleHourWithCloud room=\(rid) prevBucket=\(previousHourBucket) newBucket=\(newHourBucket) bucketSeconds=\(self.settlementBucketSeconds) pendingKE=\(String(describing: currentAllocations), privacy: .public) failedBuckets=\(String(describing: queue.sortedBuckets().map { Int($0.timeIntervalSince1970) }), privacy: .public)")
    #endif

    Task { @MainActor in
      defer { queue.endFlight(bucket: previousHourBucket) }

      do {
        // ③ Retry previously failed buckets — each using ITS OWN saved allocations
        for failedBucket in queue.sortedBuckets() {
          guard queue.tryBeginFlight(bucket: failedBucket),
                let savedAllocs = queue.allocations(for: failedBucket) else { continue }
          do {
            try await service.submitAllocations(roomId: rid, hourBucket: failedBucket, allocations: savedAllocs, bucketSeconds: settlementBucketSeconds)
            queue.remove(bucket: failedBucket)
            pendingStore.remove(roomId: rid, hourBucket: failedBucket)
            #if DEBUG
            AppLog.battle.info("[Battle] retry succeeded for failed bucket \(failedBucket)")
            #endif
          } catch {
            #if DEBUG
            AppLog.battle.info("[Battle] retry still failed for bucket \(failedBucket): \(error)")
            #endif
            // Keep in queue for the next settlement cycle
          }
          queue.endFlight(bucket: failedBucket)
        }
        // Persist the updated failed queue after retries
        queue.persist()

        // ④ Submit this hour's allocations (using the snapshot, not live pendingKE)
        try await service.submitAllocations(roomId: rid, hourBucket: previousHourBucket, allocations: currentAllocations, bucketSeconds: settlementBucketSeconds)
        pendingKE.removeAll()
        selectedCellID = nil
        if currentSpend > 0 {
          hourlyBudget = max(0, hourlyBudget - currentSpend)
          onConsumedKE?(currentSpend)
        }
        pendingStore.remove(roomId: rid, hourBucket: previousHourBucket)
        WidgetReloader.reloadAll()

        // ⑤ Fetch updated board state
        var dtos = try await service.fetchBoardState(roomId: rid, hourBucket: newHourBucket, bucketSeconds: settlementBucketSeconds)
        #if DEBUG
        AppLog.battle.info("[Battle] after settlement board cells count=\(dtos.count)")
        #endif

        let beforePlayerCount = beforeCells.filter { $0.owner == .player }.count
        let newPlayerCount = dtos.filter { $0.owner == "player" }.count
        if currentAllocations.isEmpty, beforePlayerCount > 0, newPlayerCount == 0 {
          #if DEBUG
          AppLog.battle.info("[Battle] new board has 0 player cells (suspicious), refetching once...")
          #endif
          try? await Task.sleep(nanoseconds: 400_000_000)
          if let refetched = try? await service.fetchBoardState(roomId: rid, hourBucket: newHourBucket, bucketSeconds: settlementBucketSeconds), refetched.count == BattleConstants.totalCells {
            dtos = refetched
          }
        }

        if dtos.count == BattleConstants.totalCells {
          let sorted = dtos.sorted(by: { $0.id < $1.id })
          let newCells = sorted.map(Self.makeCell(from:))
          #if DEBUG
          if !currentAllocations.isEmpty {
            for id in currentAllocations.keys.sorted() {
              let before = beforeCells[id]
              let after = newCells[id]
              AppLog.battle.info("[Battle][Debug] cell \(id) owner \(before.owner.rawValue) -> \(after.owner.rawValue) hp \(before.hpNow) -> \(after.hpNow)")
            }
          }
          #endif
          cells = newCells
        }
        if let summary = try? await service.fetchRoundSummary(roomId: rid, hourBucket: previousHourBucket, bucketSeconds: settlementBucketSeconds) {
          lastRoundSummary = summary
          lastRoundBucket = previousHourBucket
        }

      } catch {
        #if DEBUG
        AppLog.battle.info("[Battle] settleHourWithCloud error: \(error.localizedDescription, privacy: .public)")
        #endif
        // ⑥ Store the SNAPSHOT allocations for this bucket (not current pendingKE).
        //    Clear pendingKE so the next hour starts fresh; the snapshot is safely queued.
        queue.record(bucket: previousHourBucket, allocations: currentAllocations)
        pendingKE.removeAll()
        selectedCellID = nil
        // 通知使用者：本輪結算未上傳，下個整點會自動重試。
        errorMessage = AppError.networkError(error).errorDescription
      }
    }
  }

  private func settleHourLocal() {
    let attackableIds = Set((0..<cells.count).filter { isAttackableTarget($0) })
    let result = BattleSettlementEngine.settleLocal(
      cells: cells,
      pendingKE: pendingKE,
      attackableIds: attackableIds
    )

    hourlyBudget = max(0, hourlyBudget - result.spent) + result.refundable
    if result.spent > 0 {
      onConsumedKE?(result.spent)
    }

    cells = result.cells
    pendingKE.removeAll()
    selectedCellID = nil
    rollEnemyPressure()
    // 不再在每個結算週期自動把 KE 回補到基礎上限；
    // 若本輪 KE 用完，下一輪維持 0，直到使用者再透過測驗賺取 KE。
    if let rid = roomId {
      let nowBucket = currentBucket()
      let prevBucket = Date(timeIntervalSince1970: nowBucket.timeIntervalSince1970 - Double(settlementBucketSeconds))
      pendingStore.remove(roomId: rid, hourBucket: prevBucket)
    }
    WidgetReloader.reloadAll()
  }

  // MARK: - Timer & Countdown

  private func startTimer() {
    timerCancellable?.cancel()
    timerCancellable = Timer
      .publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        guard let self else { return }
        self.tick()
      }
  }

  private func tick() {
    // 避免 Timer 漂移導致「跳過 0 秒」而錯過結算：
    // 只要偵測到 bucket 起始時間已切換，就立刻結算一次。
    let bucketStart = currentBucket()
    if bucketStart > lastBucketStart {
      #if DEBUG
      AppLog.battle.info("[Battle] bucket boundary crossed. last=\(self.lastBucketStart) new=\(bucketStart)")
      #endif
      lastBucketStart = bucketStart
      settleHour()
      refreshCountdown()
      return
    }

    refreshCountdown()
    isSettlementLocked = secondsToTopOfHour <= lockoutSeconds
    if secondsToTopOfHour <= 0 {
      settleHour()
      refreshCountdown()
    }
  }

  private func refreshCountdown() {
    let now = nowProvider()
    let nowEpoch = now.timeIntervalSince1970
    let bucket = Double(settlementBucketSeconds)
    let nextBoundary = (floor(nowEpoch / bucket) + 1) * bucket
    let diff = Int(nextBoundary - nowEpoch)
    secondsToTopOfHour = max(0, diff)
  }

  // MARK: - Board bootstrap

  /// 初始 placeholder：左上 #1 = 紅隊(invited) 出發、右下 #16 = 藍隊(creator) 出發；依當前使用者顯示 player/enemy。
  private func bootstrapInitialBoard() {
    let isRedTeam: Bool = {
      guard let cid = creatorId, let me = authService?.currentUserId else { return false }
      return me != cid
    }()
    cells = (0..<BattleConstants.totalCells).map { id in
      var owner: Owner = .neutral
      var hpNow = BattleConstants.defaultCellHP
      var hpMax = BattleConstants.defaultCellMaxHP

      if id == 0 {
        // 左上 #1：紅隊(invited) 出發，固定 startingCellHP 不扣血
        owner = isRedTeam ? .player : .enemy
        hpNow = BattleConstants.startingCellHP
        hpMax = BattleConstants.startingCellHP
      } else if id == BattleConstants.totalCells - 1 {
        // 右下 #16：藍隊(creator) 出發，固定 startingCellHP 不扣血
        owner = isRedTeam ? .enemy : .player
        hpNow = BattleConstants.startingCellHP
        hpMax = BattleConstants.startingCellHP
      }

      return Cell(
        id: id,
        owner: owner,
        hpNow: hpNow,
        hpMax: hpMax,
        decayPerHour: BattleConstants.defaultDecayPerHour,
        enemyPressure: 0
      )
    }

    rollEnemyPressure()
  }

  private func rollEnemyPressure() {
    var newCells = cells
    for i in newCells.indices { newCells[i].enemyPressure = 0 }

    let candidates = (0..<BattleConstants.totalCells).filter { newCells[$0].owner != .player }
    let picks = candidates.shuffled().prefix(BattleConstants.enemyPressureCount)
    for id in picks {
      newCells[id].enemyPressure = BattleConstants.enemyPressureLevels.randomElement() ?? 60
    }
    cells = newCells
  }

  // MARK: - DTO mapping

  private static func makeCell(from dto: BoardCellDTO) -> Cell {
    Cell(
      id: dto.id,
      owner: Owner(rawValue: dto.owner) ?? .neutral,
      hpNow: dto.hp_now,
      hpMax: dto.hp_max,
      decayPerHour: dto.decay_per_hour,
      enemyPressure: dto.enemy_pressure
    )
  }
}
