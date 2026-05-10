import XCTest
@testable import KnowledgeBit

@MainActor
final class WidgetSyncServiceTests: XCTestCase {

  private var defaults: UserDefaults!
  private let suiteName = "com.knowledgebit.tests.WidgetSyncService"
  private var reloadCount = 0

  override func setUp() async throws {
    try await super.setUp()
    defaults = UserDefaults(suiteName: suiteName)!
    clearDefaults()
    reloadCount = 0
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

  private func makeService() -> WidgetSyncService {
    WidgetSyncService(defaults: defaults, reloadAll: { [weak self] in self?.reloadCount += 1 })
  }

  // MARK: - syncProfile

  func testSyncProfileWritesAllFields() {
    let svc = makeService()
    let userId = UUID()
    svc.syncProfile(displayName: "Alice", avatarURL: "https://x/avatar.png", userId: userId)

    XCTAssertEqual(defaults.string(forKey: AppGroup.Keys.displayName), "Alice")
    XCTAssertEqual(defaults.string(forKey: AppGroup.Keys.avatarURL), "https://x/avatar.png")
    XCTAssertEqual(defaults.string(forKey: AppGroup.Keys.userId), userId.uuidString)
    XCTAssertEqual(reloadCount, 1)
  }

  func testSyncProfileSkipsReloadWhenRequested() {
    let svc = makeService()
    svc.syncProfile(displayName: "Bob", avatarURL: nil, userId: nil, shouldReloadWidget: false)
    XCTAssertEqual(reloadCount, 0)
  }

  func testSyncProfileWithoutUserIdLeavesUserIdKeyUnset() {
    let svc = makeService()
    svc.syncProfile(displayName: "C", avatarURL: nil, userId: nil)
    XCTAssertNil(defaults.string(forKey: AppGroup.Keys.userId))
  }

  // MARK: - syncExp

  func testSyncExpWritesAllFields() {
    let svc = makeService()
    svc.syncExp(level: 5, exp: 80, expToNext: 100)
    XCTAssertEqual(defaults.integer(forKey: AppGroup.Keys.level), 5)
    XCTAssertEqual(defaults.integer(forKey: AppGroup.Keys.exp), 80)
    XCTAssertEqual(defaults.integer(forKey: AppGroup.Keys.expToNext), 100)
    XCTAssertEqual(reloadCount, 1)
  }

  func testSyncExpSkipsReloadWhenRequested() {
    let svc = makeService()
    svc.syncExp(level: 1, exp: 1, expToNext: 100, shouldReloadWidget: false)
    XCTAssertEqual(reloadCount, 0)
  }

  // MARK: - syncBatch

  func testSyncBatchOnlyReloadsOnceWithMultipleFields() {
    let svc = makeService()
    svc.syncBatch(
      displayName: "X",
      avatarURL: "https://x/a.png",
      userId: UUID(),
      level: 3,
      exp: 50,
      expToNext: 200
    )
    XCTAssertEqual(reloadCount, 1, "批次同步只應觸發一次 reload")
  }

  func testSyncBatchDoesNotReloadWithNoFields() {
    let svc = makeService()
    svc.syncBatch()  // 全部 nil
    XCTAssertEqual(reloadCount, 0)
  }

  func testSyncBatchClearsAvatarWhenDisplayNamePresentButAvatarNil() {
    // 先寫入頭像
    defaults.set("https://old/avatar.png", forKey: AppGroup.Keys.avatarURL)
    let svc = makeService()
    // 傳入 displayName 但 avatarURL = nil 表示「明確清除頭像」
    svc.syncBatch(displayName: "NewName", avatarURL: nil)
    XCTAssertNil(defaults.string(forKey: AppGroup.Keys.avatarURL))
    XCTAssertEqual(defaults.string(forKey: AppGroup.Keys.displayName), "NewName")
  }

  func testSyncBatchPreservesAvatarWhenOnlyExpProvided() {
    // 先寫入頭像
    defaults.set("https://kept/a.png", forKey: AppGroup.Keys.avatarURL)
    let svc = makeService()
    // 只更新 exp，不應動到 avatar
    svc.syncBatch(level: 2, exp: 10, expToNext: 100)
    XCTAssertEqual(defaults.string(forKey: AppGroup.Keys.avatarURL), "https://kept/a.png")
    XCTAssertEqual(defaults.integer(forKey: AppGroup.Keys.level), 2)
  }

  func testSyncBatchUserIdRequiresProfileFieldToBeWritten() {
    let svc = makeService()
    let userId = UUID()
    // 只傳 userId，沒傳 displayName / avatarURL → userId 不應寫入
    svc.syncBatch(userId: userId)
    XCTAssertNil(defaults.string(forKey: AppGroup.Keys.userId))
    XCTAssertEqual(reloadCount, 0, "完全沒更新時不應 reload")
  }

  // MARK: - clearProfile

  func testClearProfileRemovesProfileFieldsButKeepsExp() {
    defaults.set("Alice", forKey: AppGroup.Keys.displayName)
    defaults.set("https://x/a.png", forKey: AppGroup.Keys.avatarURL)
    defaults.set(UUID().uuidString, forKey: AppGroup.Keys.userId)
    defaults.set(10, forKey: AppGroup.Keys.level)

    let svc = makeService()
    svc.clearProfile()

    XCTAssertNil(defaults.string(forKey: AppGroup.Keys.displayName))
    XCTAssertNil(defaults.string(forKey: AppGroup.Keys.avatarURL))
    XCTAssertNil(defaults.string(forKey: AppGroup.Keys.userId))
    // EXP 不應被清掉（登出時保留也無妨，登入別的帳號會覆寫）
    XCTAssertEqual(defaults.integer(forKey: AppGroup.Keys.level), 10)
  }

  // MARK: - Nil defaults safety

  func testNilDefaultsDoesNotCrash() {
    let svc = WidgetSyncService(defaults: nil, reloadAll: { [weak self] in self?.reloadCount += 1 })
    svc.syncProfile(displayName: "x", avatarURL: nil, userId: nil)
    svc.syncExp(level: 1, exp: 1, expToNext: 1)
    svc.syncBatch(displayName: "x")
    svc.clearProfile()
    XCTAssertEqual(reloadCount, 0, "defaults 為 nil 時不應觸發 reload")
  }
}
