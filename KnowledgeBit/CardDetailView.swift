// CardDetailView.swift

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
import WidgetKit
#endif

struct CardDetailView: View {
  @Bindable var card: Card
  @Environment(\.dismiss) var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme

  @State private var showingEditSheet = false
  @State private var showingDeleteConfirmation = false

  // ✅ QA 詳解展開狀態
  @State private var showDetail = false

  var body: some View {
    Group {
      if card.kind == .quote {
        quoteDetail
      } else {
        qaDetail
      }
    }
    .navigationTitle(card.wordSet?.title ?? "卡片")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button {
            copyToPasteboard(text: card.kind == .quote ? card.title : qaCopyText)
          } label: {
            Label("複製", systemImage: "doc.on.doc")
          }

          Button {
            showingEditSheet = true
          } label: {
            Label("編輯", systemImage: "pencil")
          }

          Button(role: .destructive) {
            showingDeleteConfirmation = true
          } label: {
            Label("刪除卡片", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .sheet(isPresented: $showingEditSheet) {
      AddCardView(cardToEdit: card)
    }
    .confirmationDialog(
      "刪除卡片",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("刪除", role: .destructive) { deleteCard() }
      Button("取消", role: .cancel) {}
    } message: {
      Text("確定要刪除「\(card.title)」嗎？此操作無法復原。")
    }
  }

  private var qaCopyText: String {
    let sa = shortAnswerForDisplay
    if card.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return sa
    }
    return "\(sa)\n\n\(card.content)"
  }

  // MARK: - QA Detail (簡答 + 展開詳解)

  private var qaDetail: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(card.title)
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(.primary)
          .textSelection(.enabled)

        // ✅ 簡答（先顯示）
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("簡答")
              .font(.headline.weight(.semibold))
              .foregroundStyle(.secondary)
            Spacer()
          }

          MarkdownText(markdown: shortAnswerForDisplay, font: .body)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
        )

        // ✅ 詳細說明標題列 + 右側展開按鈕
        HStack(spacing: 10) {
          Text("詳細說明")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)

          Spacer()

          Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
              showDetail.toggle()
            }
          } label: {
            Image(systemName: "chevron.right")
              .font(.headline.weight(.semibold))
              .rotationEffect(.degrees(showDetail ? 90 : 0))
              .foregroundStyle(.secondary)
              .padding(10)
              .background(
                Circle().fill(Color.secondary.opacity(0.12))
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(showDetail ? "收合詳細說明" : "展開詳細說明")
        }
        .padding(.top, 6)

        // ✅ 展開後才顯示 Markdown 詳解
        if showDetail {
          VStack(alignment: .leading, spacing: 12) {
            if card.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              Text("（尚未填寫詳細說明）")
                .foregroundStyle(.secondary)
            } else {
              MarkdownText(markdown: card.content, font: .body)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding(16)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08), lineWidth: 1)
          )
          .transition(.opacity.combined(with: .move(edge: .top)))
        }

        Spacer(minLength: 28)
      }
      .padding(20)
    }
    .background(Color(.systemGroupedBackground))
    .onAppear {
      // 可選：每次進頁面預設收合
      showDetail = false
    }
  }

  /// ✅ 舊卡片 shortAnswer 可能是空的：用 content 第一行做 fallback
  private var shortAnswerForDisplay: String {
    let sa = card.shortAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
    if !sa.isEmpty { return sa }

    // fallback to first non-empty line of detailed content
    let lines = card.content.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
    let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
    let cleaned = first.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "（尚未填寫簡答）" : cleaned
  }

  // MARK: - Quote Detail (Premium)

  private var quoteDetail: some View {
    ZStack {
      Color(.systemGroupedBackground).ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 18) {
          HStack {
            Label("語錄卡片", systemImage: "quote.bubble.fill")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(
                Capsule(style: .continuous).fill(Color.secondary.opacity(0.10))
              )
            Spacer()
          }

          quoteCard

          HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
              .font(.footnote)
              .foregroundStyle(.secondary)
            Text("長按可選取文字，右上角可快速複製")
              .font(.footnote)
              .foregroundStyle(.secondary)
            Spacer()
          }
          .padding(.horizontal, 2)

          Spacer(minLength: 12)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 28)
      }
    }
  }

  private var quoteCard: some View {
    let corner: CGFloat = 26

    return ZStack {
      RoundedRectangle(cornerRadius: corner, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: corner, style: .continuous)
            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
        )
        .background(
          RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(LinearGradient(
              colors: [
                Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.05),
                Color.primary.opacity(0.00)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.10), radius: 18, x: 0, y: 10)

      GeometryReader { geo in
        let w = geo.size.width
        let h = geo.size.height

        Image(systemName: "quote.opening")
          .font(.system(size: min(w, h) * 0.30, weight: .bold))
          .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06))
          .position(x: w * 0.18, y: h * 0.22)

        Image(systemName: "quote.closing")
          .font(.system(size: min(w, h) * 0.30, weight: .bold))
          .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06))
          .position(x: w * 0.82, y: h * 0.78)
      }
      .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

      VStack(spacing: 16) {
        Text(card.title.trimmingCharacters(in: .whitespacesAndNewlines))
          .font(.system(size: 26, weight: .semibold, design: .serif))
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)
          .lineSpacing(6)
          .padding(.horizontal, 18)
          .padding(.top, 8)
          .textSelection(.enabled)

        RoundedRectangle(cornerRadius: 2)
          .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
          .frame(width: 90, height: 4)
          .padding(.bottom, 4)
      }
      .padding(.vertical, 34)
    }
    .frame(maxWidth: .infinity)
    .frame(minHeight: 340)
  }

  // MARK: - Actions

  private func copyToPasteboard(text: String) {
#if os(iOS)
    UIPasteboard.general.string = text
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
#endif
  }

  private func deleteCard() {
    withAnimation {
      modelContext.delete(card)
      do {
        try modelContext.save()

#if os(iOS)
        if let defaults = UserDefaults(suiteName: AppGroup.identifier) {
          do {
            let descriptor = FetchDescriptor<Card>(sortBy: [SortDescriptor(\Card.createdAt, order: .forward)])
            let allCards = try modelContext.fetch(descriptor)
            let selected: [Card] = allCards.count <= 5 ? allCards : Array(allCards.shuffled().prefix(5))
            let ids = selected.map { $0.id.uuidString }
            defaults.set(ids, forKey: "widget.selectedCardIDs")
            defaults.set(0, forKey: "widget.currentCardIndex")

            var cachedArray: [[String: String]] = []
            for c in selected {
              cachedArray.append([
                "id": c.id.uuidString,
                "title": c.title,
                "content": c.content,
                "wordSetTitle": c.wordSet?.title ?? ""
              ])
            }
            defaults.set(cachedArray, forKey: "widget.cachedCards")
            defaults.synchronize()
          } catch {
            defaults.removeObject(forKey: "widget.selectedCardIDs")
            defaults.set(0, forKey: "widget.currentCardIndex")
            defaults.removeObject(forKey: "widget.cachedCards")
            defaults.synchronize()
          }
        }

        if #available(iOS 16.0, *) {
          Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            WidgetCenter.shared.reloadTimelines(ofKind: "KnowledgeWidget")
          }
        }
#endif

        dismiss()
      } catch {
        print("❌ Failed to delete card: \(error.localizedDescription)")
      }
    }
  }
}
