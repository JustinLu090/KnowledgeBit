import XCTest
@testable import KnowledgeBit

/// 對 MCQQuestion.makeQuestions(from:) 的純函式測試。
final class MCQQuestionTests: XCTestCase {

  // MARK: - Empty / Insufficient input

  func testReturnsEmptyForZeroCards() {
    XCTAssertTrue(MCQQuestion.makeQuestions(from: []).isEmpty)
  }

  func testReturnsEmptyForSingleCard() {
    let cards = [ChallengeCard(id: UUID(), title: "apple", content: "蘋果")]
    XCTAssertTrue(MCQQuestion.makeQuestions(from: cards).isEmpty)
  }

  // MARK: - Cardinality

  func testProducesOneQuestionPerCard() {
    let cards = (0..<5).map { i in
      ChallengeCard(id: UUID(), title: "Q\(i)", content: "A\(i)")
    }
    let questions = MCQQuestion.makeQuestions(from: cards)
    XCTAssertEqual(questions.count, cards.count)
  }

  func testEachQuestionHasFourChoices() {
    let cards = (0..<10).map { i in
      ChallengeCard(id: UUID(), title: "Q\(i)", content: "A\(i)")
    }
    let questions = MCQQuestion.makeQuestions(from: cards)
    for q in questions {
      XCTAssertEqual(q.choices.count, 4, "every question must have exactly 4 choices")
    }
  }

  // MARK: - Correctness invariants

  func testCorrectAnswerAlwaysAppearsInChoices() {
    let cards = (0..<8).map { i in
      ChallengeCard(id: UUID(), title: "Q\(i)", content: "A\(i)")
    }
    let questions = MCQQuestion.makeQuestions(from: cards)
    for q in questions {
      XCTAssertTrue(q.choices.contains(q.correctAnswer),
                    "correctAnswer (\(q.correctAnswer)) must be one of the choices: \(q.choices)")
    }
  }

  func testPromptMatchesACardTitle() {
    let cards = (0..<6).map { i in
      ChallengeCard(id: UUID(), title: "Q\(i)", content: "A\(i)")
    }
    let titles = Set(cards.map(\.title))
    let questions = MCQQuestion.makeQuestions(from: cards)
    for q in questions {
      XCTAssertTrue(titles.contains(q.prompt))
    }
  }

  func testCorrectAnswerCorrespondsToPromptCard() {
    let cards = (0..<6).map { i in
      ChallengeCard(id: UUID(), title: "Q\(i)", content: "A\(i)")
    }
    let answerByPrompt = Dictionary(uniqueKeysWithValues: cards.map { ($0.title, $0.content) })
    let questions = MCQQuestion.makeQuestions(from: cards)
    for q in questions {
      XCTAssertEqual(answerByPrompt[q.prompt], q.correctAnswer,
                     "correctAnswer must match the card whose title is the prompt")
    }
  }

  // MARK: - Distractor pool behaviour

  func testTwoCardScenarioHasRepeatedDistractor() {
    // 只有 2 張卡 → pool 只有 1 個干擾項，必須重複填滿到 3 個
    let cards = [
      ChallengeCard(id: UUID(), title: "Q1", content: "A1"),
      ChallengeCard(id: UUID(), title: "Q2", content: "A2")
    ]
    let questions = MCQQuestion.makeQuestions(from: cards)
    XCTAssertEqual(questions.count, 2)
    for q in questions {
      // 4 個 choices 中應有「正確答案 1 個 + 對方答案 3 個重複」
      XCTAssertEqual(q.choices.count, 4)
      let nonCorrect = q.choices.filter { $0 != q.correctAnswer }
      XCTAssertEqual(nonCorrect.count, 3)
      XCTAssertTrue(nonCorrect.allSatisfy { $0 != q.correctAnswer })
    }
  }
}
