import XCTest
@testable import KnowledgeBit

final class DailyQuestRecordingMock: DailyQuestQuestRecording {
  enum Recorded: Equatable {
    case studyMinutes(Int)
    case wordSetCompleted
    case wordSetQuizResult(Int, Bool, QuizType)
    case expGained(Int)
  }

  var recorded: [Recorded] = []

  func recordStudyMinutes(_ minutes: Int, experienceStore: ExperienceStore) {
    recorded.append(.studyMinutes(minutes))
  }

  func recordWordSetCompleted(experienceStore: ExperienceStore) {
    recorded.append(.wordSetCompleted)
  }

  func recordWordSetQuizResult(
    accuracyPercent: Int,
    isPerfect: Bool,
    quizType: QuizType,
    experienceStore: ExperienceStore
  ) {
    recorded.append(.wordSetQuizResult(accuracyPercent, isPerfect, quizType))
  }

  func recordExpGainedToday(_ amount: Int, experienceStore: ExperienceStore) {
    recorded.append(.expGained(amount))
  }
}

final class DailyQuestQuestTypeTests: XCTestCase {

  func testQuestTypeApplyStudyMinutes() {
    let mock = DailyQuestRecordingMock()
    let exp = ExperienceStore()
    DailyQuestService.QuestType.studyMinutes(7).apply(to: mock, experienceStore: exp)
    XCTAssertEqual(mock.recorded, [.studyMinutes(7)])
  }

  func testQuestTypeApplyWordSetCompleted() {
    let mock = DailyQuestRecordingMock()
    let exp = ExperienceStore()
    DailyQuestService.QuestType.wordSetCompleted.apply(to: mock, experienceStore: exp)
    XCTAssertEqual(mock.recorded, [.wordSetCompleted])
  }

  func testQuestTypeApplyWordSetQuizResult() {
    let mock = DailyQuestRecordingMock()
    let exp = ExperienceStore()
    DailyQuestService.QuestType.wordSetQuizResult(
      accuracyPercent: 95,
      isPerfect: true,
      quizType: .general
    ).apply(to: mock, experienceStore: exp)
    XCTAssertEqual(mock.recorded, [.wordSetQuizResult(95, true, .general)])
  }

  func testQuestTypeApplyMultipleChoiceQuizResult() {
    let mock = DailyQuestRecordingMock()
    let exp = ExperienceStore()
    DailyQuestService.QuestType.wordSetQuizResult(
      accuracyPercent: 100,
      isPerfect: true,
      quizType: .multipleChoice
    ).apply(to: mock, experienceStore: exp)
    XCTAssertEqual(mock.recorded, [.wordSetQuizResult(100, true, .multipleChoice)])
  }

  func testQuestTypeApplyExpGained() {
    let mock = DailyQuestRecordingMock()
    let exp = ExperienceStore()
    DailyQuestService.QuestType.expGained(42).apply(to: mock, experienceStore: exp)
    XCTAssertEqual(mock.recorded, [.expGained(42)])
  }
}
