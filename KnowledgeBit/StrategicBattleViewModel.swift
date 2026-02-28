// StrategicBattleViewModel.swift
// Hourly strategic grid battle simulation (front-end focused)

import Foundation
import SwiftUI
import Combine

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

  /// 上一輪結算的雙方動作統整（結算後或進入畫面時填入，供 UI 顯示）
  @Published private(set) var lastRoundSummary: BattleRoundSummary? = nil
  /// 上一輪對應的 bucket 起始時間（供 UI 顯示「上一輪 09:00–10:00」）
  @Published private(set) var lastRoundBucket: Date? = nil

  /// 上次提交失敗時，該筆 allocation 對應的 bucket；下次結算時會先重送此 bucket，再處理當前 bucket
  private var lastFailedSubmitBucket: Date?

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
    if settlementBucketSeconds == 3600 { return currentHourBucket() }
    let now = nowProvider()
    let bucket = floor(now.timeIntervalSince1970 / Double(settlementBucketSeconds)) * Double(settlementBucketSeconds)
    return Date(timeIntervalSince1970: bucket)
  }

  private var lockoutSeconds: Int {
    // 正式：整點前 2 分鐘鎖定；測試縮短 bucket 時避免永遠鎖住
    if settlementBucketSeconds >= 3600 { return 120 }
    return 10
  }

  // MARK: - Init

  init(
    roomId: UUID? = nil,
    authService: AuthService? = nil,
    creatorId: UUID? = nil,
    initialKE: Int = 1000,
    settlementBucketSeconds: Int = 3600,
    onConsumedKE: ((Int) -> Void)? = nil,
    nowProvider: @escaping () -> Date = { Date() }
  ) {
    self.roomId = roomId
    self.authService = authService
    self.creatorId = creatorId
    let clampedInitial = max(0, initialKE)
    self.hourlyBudget = clampedInitial
    self.baseHourlyBudget = clampedInitial
    self.settlementBucketSeconds = max(60, settlementBucketSeconds)
    self.nowProvider = nowProvider
    self.lastBucketStart = Date.distantPast
    self.onConsumedKE = onConsumedKE
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
      print("[Battle] loadInitialBoard bucket=\(bucket) bucketSeconds=\(settlementBucketSeconds)")
      #endif
      let dtos = try await service.fetchBoardState(roomId: rid, hourBucket: bucket, bucketSeconds: settlementBucketSeconds)
      if dtos.count == 16 {
        // 依 id 排序，確保 cells[i] 對應格子 i（左上 id=0 → #1 紅隊出發，右下 id=15 → #16 藍隊出發）
        let sorted = dtos.sorted(by: { $0.id < $1.id })
        cells = sorted.map { dto in
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
      // 還原本小時已暫存的 KE 分配，下次點開仍可看到並修改
      if let loaded = pendingStore.load(roomId: rid, hourBucket: bucket), !loaded.isEmpty {
        pendingKE = loaded
        #if DEBUG
        print("[Battle] restore pendingKE from store:", loaded)
        #endif
      }
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
      print("[Battle] loadInitialBoard error:", error)
      #endif
      // Keep bootstrap board on error
    }
  }

  deinit {
    timerCancellable?.cancel()
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

  // MARK: - Neighbor / Reachability

  func neighbors(of id: Int) -> [Int] {
    let row = id / 4
    let col = id % 4
    var n: [Int] = []
    if row > 0 { n.append((row - 1) * 4 + col) }      // up
    if row < 3 { n.append((row + 1) * 4 + col) }      // down
    if col > 0 { n.append(row * 4 + (col - 1)) }      // left
    if col < 3 { n.append(row * 4 + (col + 1)) }      // right
    return n
  }

  func isEdgeCell(_ id: Int) -> Bool {
    let row = id / 4
    let col = id % 4
    return row == 0 || row == 3 || col == 0 || col == 3
  }

  /// 可進攻：與己方領地相鄰（若玩家被全滅/領地為0，外環全部可進攻）
  func isAttackableTarget(_ id: Int) -> Bool {
    let c = cells[id]
    if c.owner == .player { return false }
    if occupiedCount == 0 { return isEdgeCell(id) }   // 全滅後重新開局：外環可進攻
    return neighbors(of: id).contains(where: { cells[$0].owner == .player })
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

  /// 每格 KE 上限（與後端 hp_max 一致）
  private let perCellKECap = 400

  /// 該格本輪最多可投入的 KE：己方格子為「不超過 hpMax - hpNow」，進攻則不超過 400
  func maxAllowedKE(for id: Int) -> Int {
    let c = cells[id]
    if c.owner == .player {
      return max(0, min(perCellKECap, c.hpMax - c.hpNow))
    }
    return perCellKECap
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

    if clamped > maxForCell, maxForCell < perCellKECap {
      cellCapAlertMessage = "格子上限 \(perCellKECap)，此格目前 HP 已達 \(cells[id].hpNow)/\(cells[id].hpMax)，最多只能再投入 \(maxForCell) KE。"
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
    print("[Battle] settleHour() called; pendingKE =", pendingKE, "remainingKE =", remainingKE)
    #endif
    if let rid = roomId, let service = battleRoomService {
      settleHourWithCloud(roomId: rid, service: service)
      return
    }
    settleHourLocal()
  }

  private func settleHourWithCloud(roomId rid: UUID, service: BattleRoomService) {
    let newHourBucket = currentBucket()
    let previousHourBucket = Date(timeIntervalSince1970: newHourBucket.timeIntervalSince1970 - Double(settlementBucketSeconds))
    #if DEBUG
    print("[Battle] settleHourWithCloud room=\(rid) prevBucket=\(previousHourBucket) newBucket=\(newHourBucket) bucketSeconds=\(settlementBucketSeconds) pendingKE=", pendingKE, "lastFailedSubmitBucket=", lastFailedSubmitBucket as Any)
    #endif
    let beforeCells = cells

    Task { @MainActor in
      do {
        if let failedBucket = lastFailedSubmitBucket {
          try await service.submitAllocations(roomId: rid, hourBucket: failedBucket, allocations: pendingKE, bucketSeconds: settlementBucketSeconds)
          let spent = pendingKE.values.reduce(0, +)
          pendingKE.removeAll()
          selectedCellID = nil
          lastFailedSubmitBucket = nil
          if spent > 0 {
            hourlyBudget = max(0, hourlyBudget - spent)
            onConsumedKE?(spent)
          }
          pendingStore.remove(roomId: rid, hourBucket: failedBucket)
          WidgetReloader.reloadAll()
          if let summary = try? await service.fetchRoundSummary(roomId: rid, hourBucket: failedBucket, bucketSeconds: settlementBucketSeconds) {
            lastRoundSummary = summary
            lastRoundBucket = failedBucket
          }
        }

        let toSubmit = pendingKE
        let spent = toSubmit.values.reduce(0, +)
        try await service.submitAllocations(roomId: rid, hourBucket: previousHourBucket, allocations: toSubmit, bucketSeconds: settlementBucketSeconds)
        pendingKE.removeAll()
        selectedCellID = nil
        if spent > 0 {
          hourlyBudget = max(0, hourlyBudget - spent)
          onConsumedKE?(spent)
        }
        pendingStore.remove(roomId: rid, hourBucket: previousHourBucket)
        WidgetReloader.reloadAll()

        var dtos = try await service.fetchBoardState(roomId: rid, hourBucket: newHourBucket, bucketSeconds: settlementBucketSeconds)
        #if DEBUG
        print("[Battle] after settlement board cells count=", dtos.count)
        #endif

        let beforePlayerCount = beforeCells.filter { $0.owner == .player }.count
        let newPlayerCount = dtos.filter { $0.owner == "player" }.count
        if toSubmit.isEmpty, beforePlayerCount > 0, newPlayerCount == 0 {
          #if DEBUG
          print("[Battle] new board has 0 player cells (suspicious), refetching once...")
          #endif
          try? await Task.sleep(nanoseconds: 400_000_000)
          if let refetched = try? await service.fetchBoardState(roomId: rid, hourBucket: newHourBucket, bucketSeconds: settlementBucketSeconds), refetched.count == 16 {
            dtos = refetched
          }
        }

        if dtos.count == 16 {
          let sorted = dtos.sorted(by: { $0.id < $1.id })
          let newCells = sorted.map { dto in
            Cell(
              id: dto.id,
              owner: Owner(rawValue: dto.owner) ?? .neutral,
              hpNow: dto.hp_now,
              hpMax: dto.hp_max,
              decayPerHour: dto.decay_per_hour,
              enemyPressure: dto.enemy_pressure
            )
          }
          #if DEBUG
          if !toSubmit.isEmpty {
            let affected = toSubmit.keys.sorted()
            for id in affected {
              let before = beforeCells[id]
              let after = newCells[id]
              print("[Battle][Debug] cell", id,
                    "owner", before.owner.rawValue, "->", after.owner.rawValue,
                    "hp", before.hpNow, "->", after.hpNow)
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
        print("[Battle] settleHourWithCloud error:", error)
        #endif
        if lastFailedSubmitBucket == nil {
          lastFailedSubmitBucket = previousHourBucket
        }
      }
    }
  }

  private func settleHourLocal() {
    var refundable = 0
    var validAttacks: [Int: Int] = [:]
    var reinforces: [Int: Int] = [:]

    for (id, ke) in pendingKE {
      if ke <= 0 { continue }
      let owner = cells[id].owner
      if owner == .player {
        reinforces[id] = ke
      } else {
        if isAttackableTarget(id) {
          validAttacks[id] = ke
        } else {
          refundable += ke
        }
      }
    }

    let spent = pendingKE.values.reduce(0, +) - refundable
    if spent > 0 {
      hourlyBudget = max(0, hourlyBudget - spent) + refundable
      onConsumedKE?(spent)
    } else {
      hourlyBudget = max(0, hourlyBudget - spent) + refundable
    }

    for (id, ke) in reinforces {
      var c = cells[id]
      c.hpNow = min(c.hpMax, c.hpNow + ke)
      cells[id] = c
    }

    for i in cells.indices {
      var c = cells[i]
      if c.enemyPressure > 0 {
        c.hpNow = max(0, c.hpNow - c.enemyPressure)
      }
      c.hpNow = max(0, c.hpNow - c.decayPerHour)
      if c.hpNow == 0 {
        c.owner = .neutral
      }
      cells[i] = c
    }

    for (id, atk) in validAttacks {
      var c = cells[id]
      let defHP = c.hpNow
      if atk > defHP {
        c.owner = .player
        c.hpNow = min(c.hpMax, atk - defHP)
      } else {
        c.hpNow = max(0, defHP - atk)
        if c.hpNow == 0 { c.owner = .neutral }
      }
      cells[id] = c
    }

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
      print("[Battle] bucket boundary crossed. last=\(lastBucketStart) new=\(bucketStart)")
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

  // MARK: - Board bootstrap (UPDATED)

  /// 初始 placeholder：左上 #1 = 紅隊(invited) 出發、右下 #16 = 藍隊(creator) 出發；依當前使用者顯示 player/enemy。
  private func bootstrapInitialBoard() {
    let isRedTeam: Bool = {
      guard let cid = creatorId, let me = authService?.currentUserId else { return false }
      return me != cid
    }()
    cells = (0..<16).map { id in
      var owner: Owner = .neutral
      var hpNow = 120
      var hpMax = 400

      if id == 0 {
        // 左上 #1：紅隊(invited) 出發，固定 100 HP 不扣血
        owner = isRedTeam ? .player : .enemy
        hpNow = 100
        hpMax = 100
      } else if id == 15 {
        // 右下 #16：藍隊(creator) 出發，固定 100 HP 不扣血
        owner = isRedTeam ? .enemy : .player
        hpNow = 100
        hpMax = 100
      }

      return Cell(
        id: id,
        owner: owner,
        hpNow: hpNow,
        hpMax: hpMax,
        decayPerHour: 10,
        enemyPressure: 0
      )
    }

    rollEnemyPressure()
  }

  private func rollEnemyPressure() {
    var newCells = cells
    for i in newCells.indices { newCells[i].enemyPressure = 0 }

    let candidates = (0..<16).filter { newCells[$0].owner != .player }
    let picks = candidates.shuffled().prefix(3)
    for id in picks {
      newCells[id].enemyPressure = [30, 60, 90].randomElement() ?? 60
    }
    cells = newCells
  }
}
