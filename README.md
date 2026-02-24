# KnowledgeBit - Master Knowledge in Fragments

> **An iOS learning app that combines "Passive Input" via Home Screen Widgets with "Active Recall" via daily quizzes.**

KnowledgeBit is a flashcard learning tool designed for the modern "fragmented time" lifestyle. Unlike traditional apps that require active opening, KnowledgeBit leverages iOS **WidgetKit** to push knowledge passively to your home screen. It utilizes **App Groups** to synchronize data between the main app and the widget, creating a seamless learning loop: **Widget Browse -> App Quiz -> Streak Reward**.


## Key Features

* **Interactive iOS 17+ Widget**: Tap left/right arrows directly on the home screen to navigate through cards without opening the app. Widget intelligently selects up to 5 random cards and rotates through them automatically every 15 minutes.

* **Word Set Organization**: Organize flashcards into custom word sets (e.g., "韓文第六課", "CS – File System"). Each card belongs to a word set, making it easy to focus on specific topics or subjects.

* **Interactive Flip-Card Quiz**: Simulates a real flashcard experience with 3D flip animations to test memory. Quiz can be taken for all cards or filtered by a specific word set.

* **Streak System**: Tracks consecutive learning days with accurate calculation (practicing multiple times in the same day counts as one day). Visualizes progress with a weekly calendar strip showing the past 7 days.

* **Full CRUD Operations**: Create, read, update, and delete cards seamlessly. Edit cards directly from the detail view, or delete via swipe gestures.

* **SwiftData Integration**: Built with the latest iOS data persistence framework for efficient CRUD operations and relationship management.

* **Seamless Sync**: Implements **App Groups** to share the database between the main App and the Widget Extension, ensuring data consistency across all interfaces.

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
    groupContainer: .identifier("group.com.team.knowledgebit") // Critical for data sharing
)
```

### 2. Interactive Widget with AppIntents (iOS 17+)
The widget uses `AppIntentConfiguration` and `AppIntentTimelineProvider` to enable interactive buttons. Users can tap left/right arrows directly on the home screen to navigate cards without opening the app.

**Key Features:**
- Widget selects up to 5 random cards from all available cards
- Interactive navigation via `NextCardIntent` and `PreviousCardIntent`
- Automatic rotation every 15 minutes through the selected subset
- Persistent card selection stored in App Group UserDefaults

### 3. Word Set Organization
Cards are organized into `WordSet` collections, allowing users to group related flashcards together. Each card can belong to one word set, and quizzes can be filtered by word set.

**Data Model:**
```swift
@Model
final class WordSet {
    var id: UUID
    var title: String          // e.g. "韓文第六課"
    var level: String?         // e.g. "初級", "中級", "高級"
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var cards: [Card] = []
}
```

### 4. Accurate Streak Calculation
The streak system correctly calculates consecutive learning days:
- Multiple practice sessions in the same day count as one day
- Streak resets when a day is missed
- Uses calendar-based date comparison for accuracy

### 5. Weekly Calendar Visualization
Displays a 7-day rolling window with GitHub-style intensity levels:
- Each day shows a colored circle indicating study intensity
- Intensity levels: none (gray), low (light blue), medium, high, max (dark blue)
- Today's date is highlighted with a border

### 6. Modern UI Design
- Clean, modern iOS 17+ design language
- Custom header with settings and add buttons
- Card-based layout for streak and word sets
- Consistent spacing and visual hierarchy

## Usage

### Creating Word Sets
1. Tap the "+" button on the home screen
2. Select "新增單字集"
3. Enter a title (e.g., "韓文第六課")
4. Optionally select a level (初級/中級/高級)

### Adding Cards
1. Tap the "+" button → "新增單字"
2. Enter card title and content
3. Select a word set (optional)
4. Save the card

### Taking Quizzes
- **All Cards**: Tap "開始每日測驗" on the home screen
- **Word Set Specific**: Open a word set → Tap "開始測驗"

### Widget Usage
- **Interactive Navigation**: Tap left/right arrows on the widget to navigate cards
- **Automatic Rotation**: Widget automatically shows a different card every 15 minutes
- **Card Selection**: Widget intelligently selects up to 5 random cards and rotates through them

## Project Structure

```
KnowledgeBit/
├── KnowledgeBit/              # Main app target
│   ├── KnowledgeBitApp.swift  # App entry point with SwiftData configuration
│   ├── ContentView.swift      # Home screen with streak and word set list
│   ├── Card.swift             # Card and StudyLog models
│   ├── WordSet.swift          # WordSet model
│   ├── StatsView.swift        # Streak card with weekly calendar
│   ├── QuizView.swift         # Interactive flip-card quiz
│   ├── WordSetListView.swift  # List of all word sets
│   ├── WordSetDetailView.swift # Cards in a word set
│   ├── AddCardView.swift      # Create/edit card form
│   ├── AddWordSetView.swift   # Create word set form
│   ├── CardDetailView.swift   # Card detail with edit/delete
│   ├── FlipCardView.swift     # 3D flip animation component
│   ├── WeeklyCalendarView.swift # Weekly calendar strip component
│   └── AppGroup.swift         # Shared App Group identifier
└── KnowledgeWidget/           # Widget extension target
    └── KnowledgeWidget.swift  # Interactive widget with AppIntents
```

## Security / 敏感設定

- **Supabase**：請將 `SupabaseConfig.example.txt` 的內容複製到新檔 `SupabaseConfig.swift`，並到 [Supabase Dashboard](https://supabase.com/dashboard) → Project Settings → API 填入 **Project URL** 與 **anon public key**。`SupabaseConfig.swift` 已列於 `.gitignore`，請勿提交。
- **若曾將 `SupabaseConfig.swift` 提交至版控**：請在 Supabase Dashboard 的 API 設定中**重新產生 anon key**，並更新本機的 `SupabaseConfig.swift`，以避免舊 key 外洩風險。
- **Edge Functions（Gemini）**：API Key 請僅在 Supabase 的 Edge Function Secrets 中設定 `GEMINI_API_KEY`，勿寫入程式碼。詳見 `AI_SETUP.md`。

## Requirements

- iOS 17.0+
- Xcode 15.0+
- App Groups capability configured in Xcode Signing & Capabilities
