// WidgetReloader.swift
// Helper to reload widget timelines after data changes

import WidgetKit
import Foundation
import os

/// Helper struct to reload widget timelines when data changes in the main app
struct WidgetReloader {
  /// The widget kind identifier
  static let widgetKind = "KnowledgeWidget"
  
  /// 防抖時間間隔（秒），短時間內多次呼叫只執行一次
  private static let debounceInterval: TimeInterval = 0.5
  
  /// 最後一次刷新的時間戳
  private static var lastReloadTime: Date?
  
  /// 待執行的刷新任務
  private static var pendingTask: Task<Void, Never>?
  
  /// 線程安全的鎖
  private static let lock = NSLock()
  
  /// Reload all timelines for the KnowledgeWidget with debounce
  /// 使用防抖機制，短時間內多次呼叫只執行一次，避免重複刷新浪費電力
  /// This should be called after successful SwiftData save operations
  /// to ensure the widget reflects the latest data immediately.
  static func reloadAll() {
    lock.lock()
    defer { lock.unlock() }
    
    let now = Date()
    
    // 如果距離上次刷新時間小於防抖間隔，取消之前的任務並延遲執行
    if let lastTime = lastReloadTime,
       now.timeIntervalSince(lastTime) < debounceInterval {
      // 取消之前的待執行任務
      pendingTask?.cancel()
      
      // 創建新的延遲任務
      pendingTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
        // 檢查任務是否被取消
        guard !Task.isCancelled else { return }
        
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        lastReloadTime = Date()
        AppLog.widget.info("🔄 Widget timeline reloaded (debounced): \(widgetKind)")
      }
    } else {
      // 立即執行刷新
      lastReloadTime = now
      Task { @MainActor in
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        AppLog.widget.info("🔄 Widget timeline reloaded: \(widgetKind)")
      }
    }
  }
  
  /// 強制立即刷新（不使用防抖）
  /// 用於需要立即更新的特殊情況
  static func reloadAllImmediately() {
    lock.lock()
    defer { lock.unlock() }
    
    // 取消待執行的任務
    pendingTask?.cancel()
    pendingTask = nil
    
    lastReloadTime = Date()
    Task { @MainActor in
      WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
      AppLog.widget.info("🔄 Widget timeline reloaded (immediate): \(widgetKind)")
    }
  }
}

