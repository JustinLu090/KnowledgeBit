# KnowledgeBit - Master Knowledge in Fragments

> **An iOS learning app that combines "Passive Input" via Home Screen Widgets with "Active Recall" via daily quizzes.**

KnowledgeBit is a flashcard learning tool designed for the modern "fragmented time" lifestyle. Unlike traditional apps that require active opening, KnowledgeBit leverages iOS **WidgetKit** to push knowledge passively to your home screen. It utilizes **App Groups** to synchronize data between the main app and the widget, creating a seamless learning loop: **Widget Browse -> App Quiz -> Streak Reward**.


## Key Features

* **Widget-First Learning**: Uses WidgetKit to rotate through knowledge cards on the home screen throughout the day.
* **Interactive Flip-Card Quiz**: Simulates a real flashcard experience with 3D flip animations to test memory.
* **Streak System**: Tracks consecutive learning days and visualizes progress with a GitHub-style weekly heatmap.
* **SwiftData Integration**: Built with the latest iOS data persistence framework for efficient CRUD operations.
* **Seamless Sync**: Implements **App Groups** to share the database between the main App and the Widget Extension.

## Tech Stack

* **Language**: Swift 5.9
* **UI Framework**: SwiftUI
* **Widget**: WidgetKit
* **Persistence**: SwiftData (Core Data schema)
* **Version Control**: Git & GitHub

## Technical Highlights

### 1. App Group Data Sharing
To solve the sandbox restriction where the Widget Extension cannot access the main app's database, this project utilizes `App Groups`. The `ModelContainer` is configured to store the SQLite file in a shared container.

```swift
// Configuration in KnowledgeBitApp.swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    groupContainer: .identifier("group.com.yourname.KnowledgeBit") // Critical for data sharing
)
