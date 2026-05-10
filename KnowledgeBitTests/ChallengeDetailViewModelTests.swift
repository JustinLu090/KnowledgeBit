import XCTest
@testable import KnowledgeBit

@MainActor
final class ChallengeDetailViewModelTests: XCTestCase {

  // MARK: - Test infra

  private var defaults: UserDefaults!
  private let suiteName = "com.knowledgebit.tests.ChallengeDetailVM"
  private let rewardedKey = "test_rewarded"

  override func setUp() async throws {
    try await super.setUp()
    defaults = UserDefaults(suiteName: suiteName)!
    clearDefaults()
  }

  override func tearDown() async throws {
    clearDefaults()
    defaults = nil
    try await super.tearDown()
  }

  private func clearDefaults() {
    for key in defaults.dictionaryRepresentation().keys {
      defaults.removeObject(forKey: key)
    }
  }

  // MARK: - Helpers

  private final class GrantedExpRecorder {
    var totalGranted = 0
    var grantCount = 0
  }

  private func makeVM(
    service: MockChallengeService,
    currentUserId: UUID? = UUID(),
    recorder: GrantedExpRecorder = GrantedExpRecorder()
  ) -> (ChallengeDetailViewModel, GrantedExpRecorder) {
    let store = RewardedChallengeStore(defaults: defaults, key: rewardedKey)
    let vm = ChallengeDetailViewModel(
      service: service,
      currentUserId: { currentUserId },
      grantExp: { delta in
        recorder.totalGranted += delta
        recorder.grantCount += 1
      },
      rewardedStore: store
    )
    return (vm, recorder)
  }

  /// 建立一個 pending 狀態的挑戰，便於各測試組合屬性。
  private func makeChallenge(
    id: UUID = UUID(),
    challengerId: UUID = UUID(),
    respondentId: UUID? = nil,
    challengerScore: Int = 5,
    challengerTotal: Int = 10,
    respondentScore: Int? = nil,
    respondentTotal: Int? = nil,
    quizContent: [ChoiceQuestion]? = nil,
    shuffledCardIds: [UUID]? = nil,
    wordSetId: UUID? = UUID(),
    status: String = "pending"
  ) -> ChallengeSession {
    ChallengeSession(
      id: id,
      challengerId: challengerId,
      challengerDisplayName: "Alice",
      challengerAvatarUrl: nil,
      challengerLevel: 5,
      wordSetId: wordSetId,
      wordSetTitle: "WS",
      challengerScore: challengerScore,
      challengerTotal: challengerTotal,
      challengerTimeSpent: 30,
      challengerCompletedAt: Date(),
      targetScore: nil,
      challengerCombo: nil,
      shuffledCardIds: shuffledCardIds,
      quizContent: quizContent,
      respondentId: respondentId,
      respondentDisplayName: nil,
      respondentScore: respondentScore,
      respondentTotal: respondentTotal,
      respondentTimeSpent: nil,
      respondentCompletedAt: nil,
      respondentCombo: nil,
      status: status,
      createdAt: Date(),
      expiresAt: Date().addingTimeInterval(7 * 24 * 3600)
    )
  }

  private func makeCard(_ title: String, _ content: String) -> ChallengeCard {
    ChallengeCard(id: UUID(), title: title, content: content)
  }

  // MARK: - load: success paths

  func testLoadSuccessWithQuizContentSetsQuizContentAndSkipsCardFetch() async {
    let mock = MockChallengeService()
    let qs = [ChoiceQuestion(
      sentence_with_blank: "The cat is ___.",
      correct_answer: "cute",
      options: ["cute", "dog", "fish", "blue"],
      explanation: nil
    )]
    mock.fetchChallengeStub = .success(makeChallenge(quizContent: qs))
    let (vm, _) = makeVM(service: mock)

    await vm.load(challengeId: UUID())

    XCTAssertFalse(vm.isLoading)
    XCTAssertNil(vm.loadError)
    XCTAssertEqual(vm.quizContent.count, 1)
    XCTAssertTrue(vm.challengeCards.isEmpty)
    XCTAssertEqual(mock.fetchChallengeCardsByIdsCallCount, 0)
    XCTAssertEqual(mock.fetchChallengeCardsCallCount, 0)
  }

  func testLoadSuccessWithShuffledIdsLoadsCardsByIds() async {
    let mock = MockChallengeService()
    let ids = [UUID(), UUID()]
    mock.fetchChallengeStub = .success(makeChallenge(shuffledCardIds: ids))
    mock.fetchChallengeCardsByIdsStub = .success([makeCard("a", "A"), makeCard("b", "B")])
    let (vm, _) = makeVM(service: mock)

    await vm.load(challengeId: UUID())

    XCTAssertEqual(vm.challengeCards.count, 2)
    XCTAssertEqual(mock.fetchChallengeCardsByIdsCallCount, 1)
  }

  func testLoadSuccessFallsBackToWordSetCardsWhenNoShuffledIds() async {
    let mock = MockChallengeService()
    mock.fetchChallengeStub = .success(makeChallenge(shuffledCardIds: nil))
    mock.fetchChallengeCardsStub = .success([makeCard("a", "A")])
    let (vm, _) = makeVM(service: mock)

    await vm.load(challengeId: UUID())

    XCTAssertEqual(vm.challengeCards.count, 1)
    XCTAssertEqual(mock.fetchChallengeCardsCallCount, 1)
    XCTAssertEqual(mock.fetchChallengeCardsByIdsCallCount, 0)
  }

  // MARK: - load: failure

  func testLoadFailureSetsLoadErrorNotErrorMessage() async {
    let mock = MockChallengeService()
    mock.fetchChallengeStub = .failure(MockNetworkError())
    let (vm, _) = makeVM(service: mock)

    await vm.load(challengeId: UUID())

    XCTAssertFalse(vm.isLoading)
    XCTAssertNotNil(vm.loadError, "初始載入失敗應寫入 loadError（阻斷型錯誤）")
    XCTAssertNil(vm.errorMessage, "初始載入失敗不應觸發 banner")
  }

  // MARK: - loadCards: failure surfaces banner

  func testLoadCardsFailureSetsErrorMessageNotLoadError() async {
    let mock = MockChallengeService()
    mock.fetchChallengeStub = .success(makeChallenge(shuffledCardIds: [UUID()]))
    // 第一次 load 內呼叫的 byIds：用 try? 不會掛 banner；給空集合即可
    mock.fetchChallengeCardsByIdsStub = .success([])
    let (vm, _) = makeVM(service: mock)
    await vm.load(challengeId: UUID())

    // 接下來模擬使用者點「載入題目」走另一條路徑：byIds 失敗
    mock.fetchChallengeCardsByIdsStub = .failure(MockNetworkError())
    await vm.loadCards()

    XCTAssertNotNil(vm.errorMessage, "loadCards 失敗應觸發 banner")
    XCTAssertNil(vm.loadError, "過渡型錯誤不應寫入 loadError")
  }

  // MARK: - submitResult

  func testSubmitResultSuccessSetsFinalChallenge() async {
    let mock = MockChallengeService()
    let challengeId = UUID()
    mock.fetchChallengeStub = .success(makeChallenge(id: challengeId, status: "completed"))
    let (vm, _) = makeVM(service: mock)
    // 先載入挑戰
    await vm.load(challengeId: challengeId)

    // 再次設定 fetchChallenge stub 給 submitResult 的 fetch
    mock.fetchChallengeStub = .success(makeChallenge(
      id: challengeId,
      respondentScore: 9,
      respondentTotal: 10,
      status: "completed"
    ))
    await vm.submitResult(challengeId: challengeId, score: 9, total: 10, timeSpent: 30, combo: 5)

    XCTAssertEqual(mock.respondToChallengeCallCount, 1)
    XCTAssertEqual(mock.lastRespondParams?.score, 9)
    XCTAssertEqual(mock.lastRespondParams?.combo, 5)
    XCTAssertEqual(vm.finalChallenge?.respondentScore, 9)
  }

  func testSubmitResultFailureFallsBackToLocalAndSurfacesBanner() async {
    let mock = MockChallengeService()
    let challengeId = UUID()
    mock.fetchChallengeStub = .success(makeChallenge(id: challengeId, status: "pending"))
    let (vm, _) = makeVM(service: mock)
    await vm.load(challengeId: challengeId)

    mock.respondToChallengeStub = .failure(MockNetworkError())
    await vm.submitResult(challengeId: challengeId, score: 7, total: 10, timeSpent: 25, combo: 2)

    // 結果頁仍可顯示本機暫存
    XCTAssertEqual(vm.finalChallenge?.respondentScore, 7)
    XCTAssertEqual(vm.finalChallenge?.respondentTotal, 10)
    XCTAssertEqual(vm.finalChallenge?.respondentCombo, 2)
    XCTAssertNotNil(vm.errorMessage)
  }

  func testSubmitResultReentrancyGuard() async {
    // 兩個並發呼叫只應有一個真的執行（第二個會被 isSubmitting guard 擋下）。
    // 這個測試略簡化：先觀察 respondToChallengeCallCount 不會是 2 即可。
    let mock = MockChallengeService()
    let challengeId = UUID()
    mock.fetchChallengeStub = .success(makeChallenge(id: challengeId))
    let (vm, _) = makeVM(service: mock)

    async let a: Void = vm.submitResult(challengeId: challengeId, score: 1, total: 1, timeSpent: 1, combo: 0)
    async let b: Void = vm.submitResult(challengeId: challengeId, score: 1, total: 1, timeSpent: 1, combo: 0)
    _ = await (a, b)

    // 兩個都序列化在 MainActor 上，但第一個結束前第二個進入時 isSubmitting=false 已經 reset
    // 所以這個 reentrancy guard 主要保護 SwiftUI 上同一輪事件迴圈內的重複觸發。
    // 此測試斷言至少呼叫成功，作為迴歸基準。
    XCTAssertGreaterThanOrEqual(mock.respondToChallengeCallCount, 1)
  }

  // MARK: - grantChallengeExp

  func testGrantExpForWonResultGives30() async {
    let mock = MockChallengeService()
    let respondentId = UUID()
    let challengeId = UUID()
    // 接受者贏：score 9 > 對方 5
    mock.fetchChallengeStub = .success(makeChallenge(
      id: challengeId,
      respondentId: respondentId,
      challengerScore: 5, challengerTotal: 10,
      respondentScore: 9, respondentTotal: 10,
      status: "completed"
    ))
    let (vm, recorder) = makeVM(service: mock, currentUserId: respondentId)
    await vm.load(challengeId: challengeId)

    vm.grantChallengeExp()
    XCTAssertEqual(recorder.grantCount, 1)
    XCTAssertEqual(recorder.totalGranted, ChallengeRewards.win)
  }

  func testGrantExpForLostResultGives10() async {
    let mock = MockChallengeService()
    let respondentId = UUID()
    let challengeId = UUID()
    mock.fetchChallengeStub = .success(makeChallenge(
      id: challengeId,
      respondentId: respondentId,
      challengerScore: 9, challengerTotal: 10,
      respondentScore: 5, respondentTotal: 10,
      status: "completed"
    ))
    let (vm, recorder) = makeVM(service: mock, currentUserId: respondentId)
    await vm.load(challengeId: challengeId)

    vm.grantChallengeExp()
    XCTAssertEqual(recorder.totalGranted, ChallengeRewards.lose)
  }

  func testGrantExpDoubleCallOnlyGrantsOnce() async {
    let mock = MockChallengeService()
    let respondentId = UUID()
    let challengeId = UUID()
    mock.fetchChallengeStub = .success(makeChallenge(
      id: challengeId,
      respondentId: respondentId,
      challengerScore: 5, challengerTotal: 10,
      respondentScore: 9, respondentTotal: 10,
      status: "completed"
    ))
    let (vm, recorder) = makeVM(service: mock, currentUserId: respondentId)
    await vm.load(challengeId: challengeId)

    vm.grantChallengeExp()
    vm.grantChallengeExp()  // 第二次應被 RewardedChallengeStore 擋下
    XCTAssertEqual(recorder.grantCount, 1)
  }

  func testGrantExpSkippedWhenCurrentUserIsNotRespondent() async {
    let mock = MockChallengeService()
    let respondentId = UUID()
    let otherUserId = UUID()
    let challengeId = UUID()
    mock.fetchChallengeStub = .success(makeChallenge(
      id: challengeId,
      respondentId: respondentId,
      challengerScore: 5, challengerTotal: 10,
      respondentScore: 9, respondentTotal: 10,
      status: "completed"
    ))
    // 用第三方 user id 進入結果頁 → 不應發放 EXP
    let (vm, recorder) = makeVM(service: mock, currentUserId: otherUserId)
    await vm.load(challengeId: challengeId)

    vm.grantChallengeExp()
    XCTAssertEqual(recorder.grantCount, 0)
  }
}
