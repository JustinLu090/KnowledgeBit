// MultipleChoiceQuizView.swift
// 針對單字集的選擇題測驗，依正確性與答題速度給予 KE 分數

import SwiftUI

struct MultipleChoiceQuizView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var energyStore: BattleEnergyStore
  let wordSet: WordSet
  /// 若提供，測驗結束後可直接導向此對戰房間的戰略盤面
  let roomId: UUID?
  /// 對戰房間創辦人（藍隊）；傳給 StrategicBattleView 以顯示正確己方顏色
  let creatorId: UUID?

  init(wordSet: WordSet, roomId: UUID? = nil, creatorId: UUID? = nil) {
    self.wordSet = wordSet
    self.roomId = roomId
    self.creatorId = creatorId
  }

  @State private var questions: [Question] = []
  @State private var currentIndex: Int = 0
  @State private var showResult: Bool = false
  @State private var lastStartTime: Date = Date()
  @State private var totalKE: Int = 0
  @State private var perQuestionScores: [Int] = []
  @State private var isFinished: Bool = false
  @State private var loadError: String? = nil
  @State private var hasCommittedKE: Bool = false

  /// 一題：顯示「定義」，選項是同一單字集裡的多個單字（title）。
  struct Question: Identifiable, Equatable {
    let id = UUID()
    let prompt: String        // 題目：定義句
    let correct: String       // 正確單字（title）
    let choices: [String]     // 選項：多個 title
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        if isFinished {
          summaryView
        } else if let err = loadError {
          VStack(spacing: 12) {
            Text("無法產生題目")
              .font(.headline)
            Text(err)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if currentIndex < questions.count {
          quizCard(questions[currentIndex])
        } else {
          ProgressView()
        }
      }
      .padding(20)
      .navigationTitle("對戰測驗")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("結束") { finishQuiz() }
        }
      }
      .onAppear { setupQuestions() }
    }
  }

  // MARK: - 題目產生

  private func setupQuestions() {
    let cards = wordSet.cards
    guard !cards.isEmpty else {
      loadError = "此單字集目前沒有單字可出題。"
      return
    }

    // 先為每張卡片抽出「定義句」與單字本身（title）
    let entries: [(card: Card, term: String, definition: String)] = cards.compactMap { card in
      let def = definitionLine(from: card.content)
      let term = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !term.isEmpty, !def.isEmpty else { return nil }
      return (card, term, def)
    }

    // 至少 2 個單字，才有辦法產生「正確 + 錯誤」選項
    guard entries.count >= 2 else {
      loadError = "此單字集目前只有 1 個有定義的單字，無法產生選擇題。請為更多單字填寫「定義」。"
      return
    }

    var qs: [Question] = []

    // 最多出 10 題
    let picked = Array(entries.shuffled().prefix(10))

    for entry in picked {
      let correctTerm = entry.term
      let definition = entry.definition

      // 從其他卡片抽出錯誤選項（其他單字）
      let others = entries
        .filter { $0.card.id != entry.card.id }
        .map { $0.term }
      guard !others.isEmpty else { continue }

      let wrongs = Array(others.shuffled().prefix(3))
      let choices = ([correctTerm] + wrongs).shuffled()

      qs.append(
        Question(
          prompt: definition,
          correct: correctTerm,
          choices: choices
        )
      )
    }

    guard !qs.isEmpty else {
      loadError = "目前無法從此單字集產生足夠的選擇題。請確認每個單字都有清楚的定義內容。"
      questions = []
      return
    }

    loadError = nil
    questions = qs
    perQuestionScores = Array(repeating: 0, count: qs.count)
    currentIndex = 0
    isFinished = false
    totalKE = 0
    lastStartTime = Date()
  }

  // MARK: - 單題 UI

  @ViewBuilder
  private func quizCard(_ q: Question) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("題目 \(currentIndex + 1) / \(questions.count)")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        Text("依照下列定義選出正確單字：")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(q.prompt)
          .font(.title3.bold())
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      ForEach(q.choices, id: \.self) { choice in
        Button {
          handleAnswer(choice: choice, for: q)
        } label: {
          HStack {
            Text(choice)
              .font(.body)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(14)
          .background(Color(.secondarySystemGroupedBackground))
          .cornerRadius(12)
        }
        .buttonStyle(.plain)
      }

      Spacer(minLength: 0)
    }
  }

  // MARK: - 流程與結算

  private func handleAnswer(choice: String, for q: Question) {
    let elapsed = Date().timeIntervalSince(lastStartTime)
    let correct = (choice == q.correct)
    let score = scoreForQuestion(correct: correct, elapsed: elapsed)

    perQuestionScores[currentIndex] = score
    totalKE += score

    // 下一題
    if currentIndex + 1 < questions.count {
      currentIndex += 1
      lastStartTime = Date()
    } else {
      finishQuiz()
    }
  }

  private func finishQuiz() {
    isFinished = true
    commitKEIfNeeded()
  }

  private var summaryView: some View {
    VStack(spacing: 16) {
      Text("測驗完成")
        .font(.title2.bold())
      Text("本次獲得 KE：\(totalKE)")
        .font(.headline)

      HStack(spacing: 12) {
        Button {
          commitKEIfNeeded()
          dismiss()
        } label: {
          Text("存入 KE 並返回")
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)

        if let roomId = roomId {
          NavigationLink {
            StrategicBattleView(roomId: roomId, wordSetID: wordSet.id, creatorId: creatorId, wordSetTitle: wordSet.title)
          } label: {
            Text("前往對戰模式")
              .font(.system(size: 16, weight: .bold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }

      Button("再測一次") {
        commitKEIfNeeded()
        setupQuestions()
      }
      .padding(.top, 4)
    }
  }

  // MARK: - 計分規則

  private func scoreForQuestion(correct: Bool, elapsed: Double) -> Int {
    guard correct else { return 0 }
    let base = 10
    let fullBonusTime = 3.0
    let maxBonusTime = 8.0
    let bonus: Int
    if elapsed <= fullBonusTime { bonus = 10 }
    else if elapsed >= maxBonusTime { bonus = 0 }
    else {
      let ratio = (elapsed - fullBonusTime) / (maxBonusTime - fullBonusTime)
      bonus = max(0, 10 - Int(ratio * 10))
    }
    return base + bonus
  }

  // MARK: - 內容解析：從卡片背面抓出「定義」那一句
  // MARK: - KE commit helper

  private func commitKEIfNeeded() {
    guard !hasCommittedKE, totalKE > 0 else { return }
    energyStore.addKE(totalKE, namespace: wordSet.id.uuidString)
    hasCommittedKE = true
  }

  /// 從卡片內容擷取一個較短的定義句：
  /// 優先使用「定義」這一行的下一行，否則退回到第一個非空、且不是「定義/例句」等標題的行。
  private func definitionLine(from content: String) -> String {
    let normalized = content
      .replacingOccurrences(of: "\r", with: "")
      .components(separatedBy: "\n")

    let set = CharacterSet.whitespacesAndNewlines

    // 嘗試找到標題為「定義」的行，取其下一個非空行作為定義
    if let defIndex = normalized.firstIndex(where: { $0.trimmingCharacters(in: set) == "定義" }) {
      let nextSlice = normalized.suffix(from: normalized.index(after: defIndex))
      if let line = nextSlice.first(where: { !$0.trimmingCharacters(in: set).isEmpty }) {
        return line.trimmingCharacters(in: set)
      }
    }

    // 否則 fallback：取第一個非空、且不是「定義」/「例句」這類標題的行
    if let first = normalized.first(where: {
      let trimmed = $0.trimmingCharacters(in: set)
      return !trimmed.isEmpty && trimmed != "定義" && trimmed != "例句"
    }) {
      return first.trimmingCharacters(in: set)
    }

    return ""
  }
}

