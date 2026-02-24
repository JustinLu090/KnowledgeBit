// WordSetDetailView.swift
// Detail view showing cards in a word set and quiz option

import SwiftUI
import SwiftData
import WidgetKit

struct WordSetDetailView: View {
  @Bindable var wordSet: WordSet
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject var taskService: TaskService
  @EnvironmentObject var experienceStore: ExperienceStore
  @EnvironmentObject var questService: DailyQuestService
  @EnvironmentObject var authService: AuthService
  @State private var showingQuiz = false
  @State private var showingChoiceQuiz = false
  @State private var generatedQuestions: [ChoiceQuestion]?
  @State private var quizGenerateError: String?
  @State private var isGeneratingQuiz = false

  // Fetch cards for this word set
  private var cards: [Card] {
    wordSet.cards.sorted { $0.createdAt > $1.createdAt }
  }

  var body: some View {
    ZStack {
      Color(.systemGroupedBackground)
        .ignoresSafeArea()

      content
    }
    .navigationTitle(wordSet.title)
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        NavigationLink {
          AddCardView(wordSet: wordSet)
        } label: {
          Label("新增單字", systemImage: "plus")
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      if !cards.isEmpty {
        VStack(spacing: 10) {
          Button(action: { showingQuiz = true }) {
            HStack {
              Image(systemName: "play.fill")
              Text("開始測驗")
                .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
          Button(action: startChoiceQuiz) {
            HStack {
              Image(systemName: "list.bullet.rectangle.fill")
              Text("選擇題測驗")
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(10)
          }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
      }
    }
    .fullScreenCover(isPresented: $showingQuiz) {
      QuizView(cards: cards)
        .environmentObject(taskService)
        .environmentObject(experienceStore)
        .environmentObject(questService)
    }
    .fullScreenCover(isPresented: $showingChoiceQuiz) {
      choiceQuizCoverContent
        .environmentObject(taskService)
        .environmentObject(experienceStore)
        .environmentObject(questService)
    }
  }

  private func startChoiceQuiz() {
    showingChoiceQuiz = true
    isGeneratingQuiz = true
    quizGenerateError = nil
    generatedQuestions = nil
    Task {
      do {
        let q = try await AIService(client: authService.getClient()).generateQuizQuestions(cards: cards, targetLanguage: wordSet.title)
        await MainActor.run {
          generatedQuestions = q
          isGeneratingQuiz = false
        }
      } catch {
        await MainActor.run {
          quizGenerateError = error.localizedDescription
          isGeneratingQuiz = false
        }
      }
    }
  }

  @ViewBuilder
  private var choiceQuizCoverContent: some View {
    if isGeneratingQuiz {
      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.2)
        Text("正在產生題目…")
          .font(.headline)
          .foregroundStyle(.secondary)
        Text("可能需要 30～60 秒，請稍候")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let err = quizGenerateError {
      VStack(spacing: 20) {
        Text("無法產生題目")
          .font(.title2)
          .bold()
        Text(err)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
        if err.contains("timed out") || err.contains("逾時") {
          Text("可點「重試」再試一次（第二次通常較快）")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        HStack(spacing: 16) {
          Button("重試") {
            quizGenerateError = nil
            startChoiceQuiz()
          }
          Button("關閉") {
            showingChoiceQuiz = false
            quizGenerateError = nil
          }
          .padding()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let q = generatedQuestions, !q.isEmpty {
      ChoiceQuizView(questions: q) { score, total in
        recordChoiceQuizResult(score: score, total: total)
        showingChoiceQuiz = false
        generatedQuestions = nil
      }
    } else if generatedQuestions != nil {
      VStack(spacing: 16) {
        Text("未產生題目")
          .font(.headline)
        Button("關閉") {
          showingChoiceQuiz = false
          generatedQuestions = nil
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func recordChoiceQuizResult(score: Int, total: Int) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let log = StudyLog(date: today, cardsReviewed: score, totalCards: total)
    modelContext.insert(log)
    try? modelContext.save()
    questService.recordWordSetCompleted(experienceStore: experienceStore)
    let accuracy = total > 0 ? Int(Double(score) / Double(total) * 100) : 0
    questService.recordWordSetQuizResult(accuracyPercent: accuracy, isPerfect: (total > 0 && score == total), quizType: .multipleChoice, experienceStore: experienceStore)
  }

  private var content: some View {
    Group {
      if cards.isEmpty {
        ContentUnavailableView(
          "尚無單字",
          systemImage: "tray.fill",
          description: Text("點擊右上角 + 新增單字到此單字集")
        )
        .padding()
      } else {
        ScrollView {
          LazyVStack(spacing: 14) {
            ForEach(cards) { card in
              NavigationLink {
                CardDetailView(card: card)
              } label: {
                PremiumCardRowView(card: card)
              }
              .buttonStyle(.plain)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                  deleteCard(card)
                } label: {
                  Label("刪除", systemImage: "trash")
                }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 10)
          .padding(.bottom, 90) // avoid bottom CTA overlap
        }
      }
    }
  }

  private var bottomCTA: some View {
    Group {
      if !cards.isEmpty {
        Button(action: { showingQuiz = true }) {
          HStack(spacing: 10) {
            Image(systemName: "play.fill")
              .font(.headline.weight(.semibold))
            Text("開始測驗")
              .font(.headline.weight(.semibold))
          }
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .foregroundStyle(.white)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(Color.accentColor)
          )
          .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.thinMaterial)
      }
    }
  }

  private func deleteCard(_ card: Card) {
    withAnimation {
      modelContext.delete(card)

      do {
        try modelContext.save()
        WidgetReloader.reloadAll()
      } catch {
        print("❌ Failed to delete card: \(error.localizedDescription)")
      }
    }
  }
}
