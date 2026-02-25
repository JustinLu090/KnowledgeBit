// WordSet+IconFields.swift
// Adds icon-related optional properties so AddWordSetView compiles

import Foundation
import SwiftData

extension WordSet {
  // Optional, non-persistent fallback if your model already defines these.
  // If WordSet is a SwiftData @Model, you should move these into the model
  // definition to persist them. For now we declare them here as stored vars
  // assuming WordSet is a class reference type accessible here.

  private struct IconStorage {
    static var iconTypeKey = "iconTypeKey"
    static var iconEmojiKey = "iconEmojiKey"
    static var iconImageDataKey = "iconImageDataKey"
  }
}

// If WordSet is a class, we can add stored properties only via associated objects.
// To avoid runtime complexity, provide default-backed computed properties using
// Swift associated objects pattern available when bridging to Objective-C is possible.
// As a safe, portable fallback, define properties in a global map keyed by ObjectIdentifier.

private var iconTypeMap: [ObjectIdentifier: WordSetIconType] = [:]
private var iconEmojiMap: [ObjectIdentifier: String] = [:]
private var iconImageDataMap: [ObjectIdentifier: Data] = [:]

extension WordSet {
  var iconType: WordSetIconType? {
    get { iconTypeMap[ObjectIdentifier(self)] }
    set { iconTypeMap[ObjectIdentifier(self)] = newValue }
  }

  var iconEmoji: String? {
    get { iconEmojiMap[ObjectIdentifier(self)] }
    set { iconEmojiMap[ObjectIdentifier(self)] = newValue }
  }

  var iconImageData: Data? {
    get { iconImageDataMap[ObjectIdentifier(self)] }
    set { iconImageDataMap[ObjectIdentifier(self)] = newValue }
  }
}
