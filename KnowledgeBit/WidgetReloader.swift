// WidgetReloader.swift
// Helper to reload widget timelines after data changes

import WidgetKit
import Foundation

/// Helper struct to reload widget timelines when data changes in the main app
struct WidgetReloader {
  /// The widget kind identifier
  static let widgetKind = "KnowledgeWidget"
  
  /// Reload all timelines for the KnowledgeWidget
  /// This should be called after successful SwiftData save operations
  /// to ensure the widget reflects the latest data immediately.
  static func reloadAll() {
    Task { @MainActor in
      WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
      print("🔄 Widget timeline reloaded: \(widgetKind)")
    }
  }
}

