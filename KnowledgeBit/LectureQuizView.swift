import SwiftUI

struct LectureQuizView: View {
  let result: LectureAIResult

  @State private var mode: QuizMode = .multipleChoice
  @State private var selectedMCQ: [Int: Int] = [:]
  @State private var fillAnswers: [Int: String] = [:]
  @State private var checkedFill: Set<Int> = []

  enum QuizMode: String, CaseIterable, Identifiable {
    case multipleChoice = "選擇題"
    case fillInBlank = "填充題"

    var id: String { rawValue }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        summaryCard

        Picker("題型", selection: $mode) {
          ForEach(QuizMode.allCases) { m in
            Text(m.rawValue).tag(m)
          }
        }
        .pickerStyle(.segmented)

        if mode == .multipleChoice {
          multipleChoiceSection
        } else {
          fillInBlankSection
        }
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("講義測驗")
    .navigationBarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  private var multipleChoiceSection: some View {
    if result.quiz.multiple_choice.isEmpty {
      contentCard {
        Text("目前沒有可用的選擇題。")
          .foregroundStyle(.secondary)
      }
    } else {
      ForEach(Array(result.quiz.multiple_choice.enumerated()), id: \.offset) { index, item in
        contentCard {
          Text("第 \(index + 1) 題")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(item.question)
            .font(.headline)
            .padding(.bottom, 4)
          ForEach(Array(item.options.enumerated()), id: \.offset) { optionIndex, option in
            Button {
              selectedMCQ[index] = optionIndex
            } label: {
              HStack {
                Text(["A", "B", "C", "D"][optionIndex])
                  .font(.caption.weight(.bold))
                  .foregroundStyle(.secondary)
                  .frame(width: 22, height: 22)
                  .background(Circle().fill(Color(.tertiarySystemFill)))
                Text(option)
                Spacer()
                if selectedMCQ[index] == optionIndex {
                  Image(systemName: optionIndex == item.correct_index ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(optionIndex == item.correct_index ? .green : .red)
                }
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 8)
              .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .fill(selectedMCQ[index] == optionIndex ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
              )
            }
            .buttonStyle(.plain)
          }
          if let selected = selectedMCQ[index] {
            VStack(alignment: .leading, spacing: 6) {
              Text(selected == item.correct_index ? "答對了" : "正確答案：\(item.options[item.correct_index])")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected == item.correct_index ? .green : .orange)
              Text(item.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
            )
          }
        }
      }
    }
  }

  @ViewBuilder
  private var fillInBlankSection: some View {
    if result.quiz.fill_in_blank.isEmpty {
      contentCard {
        Text("目前沒有可用的填充題。")
          .foregroundStyle(.secondary)
      }
    } else {
      ForEach(Array(result.quiz.fill_in_blank.enumerated()), id: \.offset) { index, item in
        contentCard {
          Text("第 \(index + 1) 題")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(item.sentence)
            .font(.headline)
          TextField("輸入答案", text: Binding(
            get: { fillAnswers[index, default: ""] },
            set: { fillAnswers[index] = $0 }
          ))
          .textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.never)

          Button("檢查答案") {
            checkedFill.insert(index)
          }
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity, alignment: .leading)
          .disabled(fillAnswers[index, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if checkedFill.contains(index) {
            let userInput = fillAnswers[index, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            let isCorrect = userInput.caseInsensitiveCompare(item.answer) == .orderedSame
            VStack(alignment: .leading, spacing: 6) {
              Text(isCorrect ? "答對了" : "正確答案：\(item.answer)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCorrect ? .green : .orange)
              Text(item.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
            )
          }
        }
      }
    }
  }

  private var summaryCard: some View {
    HStack(spacing: 14) {
      statPill(title: "選擇題", value: result.quiz.multiple_choice.count, color: .blue, icon: "list.bullet.clipboard")
      statPill(title: "填空題", value: result.quiz.fill_in_blank.count, color: .orange, icon: "square.and.pencil")
    }
  }

  private func statPill(title: String, value: Int, color: Color, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: icon)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("\(value) 題")
        .font(.title3.weight(.semibold))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color(.secondarySystemBackground))
    )
  }

  private func contentCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color(.systemBackground))
    )
  }
}
