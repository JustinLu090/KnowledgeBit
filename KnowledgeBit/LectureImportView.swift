import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import WidgetKit

struct LectureImportView: View {
  @Bindable var wordSet: WordSet
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var authService: AuthService

  @State private var selectedFileName: String?
  @State private var selectedPDFData: Data?
  @State private var uploadedStoragePath: String?
  @State private var showingFileImporter = false
  @State private var language: OutputLanguage = .traditionalChinese
  @State private var isGenerating = false
  @State private var isImporting = false
  @State private var generatingLabel: String?
  @State private var result: LectureAIResult?
  @State private var statusMessage: String?

  enum OutputLanguage: String, CaseIterable, Identifiable {
    case traditionalChinese = "繁體中文"
    case english = "English"

    var id: String { rawValue }
    var payload: String { rawValue }
  }

  var body: some View {
    List {
      Section("講義檔案") {
        Button {
          showingFileImporter = true
        } label: {
          HStack {
            Image(systemName: "doc.text")
            Text(selectedFileName ?? "選擇 PDF 檔案")
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if let selectedFileName {
          Text("已選擇：\(selectedFileName)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section("生成設定") {
        Picker("輸出語言", selection: $language) {
          ForEach(OutputLanguage.allCases) { option in
            Text(option.rawValue).tag(option)
          }
        }
        .pickerStyle(.segmented)
      }

      Section("生成內容") {
        generateActionButton(
          title: "生成摘要",
          subtitle: "提煉講義核心重點",
          icon: "text.alignleft",
          color: .blue,
          task: .summary,
          loadingLabel: "摘要"
        )
        .disabled(selectedPDFData == nil || isGenerating || isImporting)

        generateActionButton(
          title: "生成學習卡",
          subtitle: "提取術語與定義配對",
          icon: "rectangle.on.rectangle.angled",
          color: .green,
          task: .flashcards,
          loadingLabel: "學習卡"
        )
        .disabled(selectedPDFData == nil || isGenerating || isImporting)

        generateActionButton(
          title: "生成測驗",
          subtitle: "建立選擇題與填空題",
          icon: "checklist",
          color: .orange,
          task: .quiz,
          loadingLabel: "測驗"
        )
        .disabled(selectedPDFData == nil || isGenerating || isImporting)
      }

      if let result {
        if !result.summary.isEmpty {
          Section("摘要") {
            VStack(alignment: .leading, spacing: 10) {
              Label("重點摘要", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
              MarkdownText(markdown: result.summary)
            }
            .padding(10)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
            )
          }
        }

        if !result.flashcards.isEmpty {
          Section("學習卡預覽") {
            Text("共 \(result.flashcards.count) 張")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach(result.flashcards.prefix(5), id: \.term) { card in
              VStack(alignment: .leading, spacing: 4) {
                Text(card.term)
                  .font(.headline)
                Text(card.definition)
                  .font(.subheadline)
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

        if !result.flashcards.isEmpty || !result.quiz.multiple_choice.isEmpty || !result.quiz.fill_in_blank.isEmpty {
          Section("匯入與測驗") {
            if !result.flashcards.isEmpty {
              Button {
                Task { await importFlashcards(result.flashcards) }
              } label: {
                HStack {
                  if isImporting { ProgressView() }
                  Text(isImporting ? "匯入中…" : "匯入學習卡到目前單字集")
                }
                .frame(maxWidth: .infinity)
              }
              .disabled(isImporting || isGenerating)
            }

            if !result.quiz.multiple_choice.isEmpty || !result.quiz.fill_in_blank.isEmpty {
              NavigationLink("開始講義測驗") {
                LectureQuizView(result: result)
              }
            }
          }
        }
      }

    }
    .navigationTitle("匯入講義")
    .navigationBarTitleDisplayMode(.inline)
    .fileImporter(
      isPresented: $showingFileImporter,
      allowedContentTypes: [UTType.pdf],
      allowsMultipleSelection: false
    ) { selection in
      switch selection {
      case .success(let urls):
        guard let url = urls.first else { return }
        loadSelectedPDF(url: url)
      case .failure(let error):
        statusMessage = "選擇檔案失敗：\(error.localizedDescription)"
      }
    }
  }

  @ViewBuilder
  private func generateActionButton(
    title: String,
    subtitle: String,
    icon: String,
    color: Color,
    task: LectureGenerateTask,
    loadingLabel: String
  ) -> some View {
    Button {
      Task { await generateSection(task) }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.title3.weight(.semibold))
          .foregroundStyle(color)
          .frame(width: 32)
        VStack(alignment: .leading, spacing: 2) {
          Text(isGenerating && generatingLabel == loadingLabel ? "\(title)中…" : title)
            .font(.headline)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if isGenerating && generatingLabel == loadingLabel {
          ProgressView()
        } else {
          Image(systemName: "arrow.right.circle.fill")
            .foregroundStyle(color)
        }
      }
      .padding(10)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color(.secondarySystemBackground))
      )
    }
    .buttonStyle(.plain)
  }

  private func generateSection(_ task: LectureGenerateTask) async {
    guard selectedPDFData != nil, let selectedFileName else { return }
    guard let userId = authService.currentUserId else {
      statusMessage = "請先登入後再使用講義分析。"
      return
    }
    let taskLabel: String = {
      switch task {
      case .summary: return "摘要"
      case .flashcards: return "學習卡"
      case .quiz: return "測驗"
      case .all: return "內容"
      }
    }()
    isGenerating = true
    generatingLabel = taskLabel
    defer {
      isGenerating = false
      generatingLabel = nil
    }

    do {
      let service = AIService(client: authService.getClient())
      let storagePath = try await ensureUploadedStoragePath(
        service: service,
        userId: userId,
        filename: selectedFileName
      )
      let generated = try await service.generateLectureMaterials(
        storagePath: storagePath,
        task: task,
        language: language.payload
      )
      result = mergeResult(current: result, incoming: generated, task: task)
      statusMessage = "\(taskLabel)生成完成。"
    } catch {
      statusMessage = "生成失敗：\(error.localizedDescription)"
    }
  }

  private func ensureUploadedStoragePath(
    service: AIService,
    userId: UUID,
    filename: String
  ) async throws -> String {
    if let uploadedStoragePath {
      return uploadedStoragePath
    }
    guard let selectedPDFData else {
      throw AIServiceError.invalidLectureFile("請先選擇 PDF 檔案")
    }
    let path = try await service.uploadLecturePDF(filename: filename, data: selectedPDFData, userId: userId)
    uploadedStoragePath = path
    return path
  }

  private func mergeResult(current: LectureAIResult?, incoming: LectureAIResult, task: LectureGenerateTask) -> LectureAIResult {
    let base = current ?? LectureAIResult(
      summary: "",
      flashcards: [],
      quiz: LectureQuizPayload(multiple_choice: [], fill_in_blank: [])
    )
    switch task {
    case .summary:
      return LectureAIResult(summary: incoming.summary, flashcards: base.flashcards, quiz: base.quiz)
    case .flashcards:
      return LectureAIResult(summary: base.summary, flashcards: incoming.flashcards, quiz: base.quiz)
    case .quiz:
      return LectureAIResult(summary: base.summary, flashcards: base.flashcards, quiz: incoming.quiz)
    case .all:
      return incoming
    }
  }

  private func loadSelectedPDF(url: URL) {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess { url.stopAccessingSecurityScopedResource() }
    }

    do {
      let data = try Data(contentsOf: url)
      guard !data.isEmpty else {
        statusMessage = "選擇的 PDF 為空檔案。"
        return
      }
      selectedPDFData = data
      selectedFileName = url.lastPathComponent
      uploadedStoragePath = nil
      result = nil
      statusMessage = nil
    } catch {
      statusMessage = "無法讀取 PDF：\(error.localizedDescription)"
    }
  }

  private func importFlashcards(_ cards: [LectureFlashcardItem]) async {
    isImporting = true
    defer { isImporting = false }

    let existing = Set(wordSet.cards.map { normalized($0.title) })
    var seen = existing
    var inserted: [Card] = []

    for item in cards {
      let title = compact(item.term)
      let key = normalized(title)
      guard !title.isEmpty, !key.isEmpty, !seen.contains(key) else { continue }
      seen.insert(key)

      let card = Card(
        title: title,
        content: "定義\n\n\(compact(item.definition))",
        wordSet: wordSet
      )
      modelContext.insert(card)
      inserted.append(card)
    }

    do {
      try modelContext.save()
      WidgetReloader.reloadAll()
      if let sync = CardWordSetSyncService.createIfLoggedIn(authService: authService) {
        Task {
          await sync.syncWordSet(wordSet)
          for card in inserted {
            await sync.syncCard(card)
          }
        }
      }
      statusMessage = "匯入完成：新增 \(inserted.count) 張（略過 \(cards.count - inserted.count) 張重複）。"
    } catch {
      statusMessage = "匯入失敗：\(error.localizedDescription)"
    }
  }

  private func compact(_ raw: String) -> String {
    raw
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private func normalized(_ raw: String) -> String {
    compact(raw).lowercased()
  }
}
