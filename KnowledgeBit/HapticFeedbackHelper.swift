// HapticFeedbackHelper.swift
// Safe haptic feedback wrapper that checks for device support

#if canImport(UIKit)
import UIKit
import CoreHaptics

enum HapticFeedbackHelper {
  /// Check if the current device supports haptics
  static var supportsHaptics: Bool {
    #if targetEnvironment(simulator)
    // Simulator doesn't support haptics
    return false
    #else
    // Check if device has haptic engine capability
    if #available(iOS 13.0, *) {
      let hapticCapability = CHHapticEngine.capabilitiesForHardware()
      return hapticCapability.supportsHaptics
    } else {
      // Fallback: UIImpactFeedbackGenerator works on all real devices
      return true
    }
    #endif
  }
  
  /// Play a light impact haptic feedback (safe for simulator)
  static func light() {
    guard supportsHaptics else { return }
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
  }
  
  /// Play a medium impact haptic feedback
  static func medium() {
    guard supportsHaptics else { return }
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
  }
  
  /// Play a heavy impact haptic feedback
  static func heavy() {
    guard supportsHaptics else { return }
    let generator = UIImpactFeedbackGenerator(style: .heavy)
    generator.impactOccurred()
  }
  
  /// Play a selection haptic feedback (for picker changes, etc.)
  static func selection() {
    guard supportsHaptics else { return }
    let generator = UISelectionFeedbackGenerator()
    generator.selectionChanged()
  }
  
  /// Play a notification haptic feedback (success, warning, error)
  static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    guard supportsHaptics else { return }
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(type)
  }
}

#else
// Fallback for environments without UIKit (e.g., Widget Extension)
enum HapticFeedbackHelper {
  static var supportsHaptics: Bool {
    return false
  }
  
  static func light() {}
  static func medium() {}
  static func heavy() {}
  static func selection() {}
  static func notification(_ type: Any) {}
}
#endif

