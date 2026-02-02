# PATCO Schedule iOS App

A native iOS application that displays real-time train schedules for the PATCO Speedline, which runs between Lindenwold, New Jersey and Philadelphia, Pennsylvania.

## Table of Contents

- [What This App Does](#what-this-app-does)
- [Requirements](#requirements)
- [Installation](#installation)
- [Running the App](#running-the-app)
- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [How Data Flows](#how-data-flows)
- [Key Concepts Explained](#key-concepts-explained)
- [Troubleshooting](#troubleshooting)

---

## What This App Does

This app helps PATCO riders know when the next train is coming. Users can:

- **Select their home station** from the 14 PATCO stations
- **See the next train** in both directions (to Philadelphia or to Lindenwold)
- **View the full schedule** for any station
- **Browse all stations** and see upcoming trains at each

The app works offline using bundled schedule data and automatically updates when connected to the internet.

---

## Requirements

Before you can run this app, you need:

### Hardware
- A Mac computer (MacBook, iMac, Mac Mini, etc.)
- Optionally, an iPhone or iPad for testing on a real device

### Software
- **macOS 13.0 (Ventura)** or later
- **Xcode 15.0** or later (free from the Mac App Store)
- **iOS 17.0** or later (for running on a device or simulator)

### How to Check Your Versions

1. **macOS version**: Click the Apple menu () → "About This Mac"
2. **Xcode version**: Open Xcode → Click "Xcode" in the menu bar → "About Xcode"

### Installing Xcode

If you don't have Xcode installed:

1. Open the **App Store** on your Mac
2. Search for "Xcode"
3. Click "Get" and then "Install"
4. Wait for the download (it's large, about 12GB)
5. Once installed, open Xcode once to complete setup

---

## Installation

### Step 1: Get the Code

If you received this as a ZIP file:
1. Double-click the ZIP file to extract it
2. Move the extracted folder to a convenient location (like your Documents folder)

If you're using Git:
```bash
# Open Terminal and run:
git clone <repository-url>
cd patco-schedule-ios
```

### Step 2: Open the Project

1. Find the folder containing the code
2. Look for a file called `PATCOSchedule.xcodeproj` (it has a blue icon)
3. Double-click it to open in Xcode

**Alternative method:**
1. Open Xcode
2. Click "File" → "Open..."
3. Navigate to the project folder
4. Select `PATCOSchedule.xcodeproj`
5. Click "Open"

### Step 3: Wait for Xcode to Index

When you first open the project, Xcode needs to process all the files. You'll see a progress bar at the top of the window. Wait for this to complete before trying to run the app.

---

## Running the App

### Running on the Simulator (Recommended for Beginners)

The simulator lets you test the app without a physical iPhone.

1. **Select a simulator**: At the top of the Xcode window, you'll see a dropdown that might say "Any iOS Device". Click it and choose a simulator like "iPhone 15" or "iPhone 15 Pro"

2. **Click the Play button**: Click the triangular "Play" button (▶) in the top-left corner, or press `Cmd + R`

3. **Wait for the build**: Xcode will compile the code. This might take a minute the first time.

4. **The simulator opens**: A window that looks like an iPhone will appear with your app running!

### Running on a Physical Device

To run on your iPhone or iPad:

1. **Connect your device** to your Mac with a USB cable
2. **Trust your Mac** on your device if prompted
3. **Select your device** from the dropdown at the top of Xcode
4. **Sign in to Apple Developer** (free):
   - Go to Xcode → Settings → Accounts
   - Click "+" and sign in with your Apple ID
5. **Set up signing**:
   - Click on "PATCOSchedule" in the left sidebar (the blue project icon)
   - Click "Signing & Capabilities"
   - Check "Automatically manage signing"
   - Select your "Team" (your Apple ID)
6. **Click Play** (▶) or press `Cmd + R`
7. **Trust the developer** on your device:
   - On your iPhone, go to Settings → General → VPN & Device Management
   - Tap your developer account and tap "Trust"

### Stopping the App

- Click the square "Stop" button (◼) in Xcode, or press `Cmd + .`

---

## Project Structure

Here's what each folder and file does:

```
patco-schedule-ios/
├── PATCOSchedule.xcodeproj     # Xcode project file (don't edit directly)
├── PATCOSchedule/              # Main app code
│   ├── PATCOScheduleApp.swift  # App entry point (where the app starts)
│   ├── ContentView.swift       # Main screen layout and navigation
│   ├── Info.plist              # App configuration (name, permissions, etc.)
│   ├── PrivacyInfo.xcprivacy   # Privacy declarations for App Store
│   ├── Assets.xcassets/        # Images and colors
│   ├── Models/                 # Data structures
│   │   ├── GTFSModels.swift           # Train schedule data models
│   │   └── PATCOActivityAttributes.swift # Live Activity data structure
│   ├── Views/                  # User interface screens
│   │   ├── StationListView.swift    # List of stations
│   │   ├── NextTrainView.swift      # Shows next train times
│   │   ├── StationDetailView.swift  # Full schedule for a station
│   │   └── TrainRowView.swift       # Single train row display
│   └── Services/               # Business logic and data handling
│       ├── ScheduleService.swift     # Main schedule manager
│       ├── GTFSParser.swift          # Downloads and parses GTFS data
│       ├── PDFScheduleParser.swift   # Parses PDF schedules (backup)
│       ├── BundledScheduleData.swift # Offline schedule data
│       ├── DataSourceManager.swift   # Coordinates data sources
│       ├── NetworkMonitor.swift      # Tracks internet connection
│       └── LiveActivityManager.swift # Manages Live Activity
├── PATCOWidgets/               # Widget Extension for Live Activity
│   ├── PATCOWidgetsBundle.swift     # Widget extension entry point
│   ├── PATCOLiveActivity.swift      # Lock Screen and Dynamic Island UI
│   └── Info.plist                   # Widget extension configuration
└── PATCOScheduleTests/         # Automated tests
    ├── GTFSModelsTests.swift
    ├── BundledScheduleDataTests.swift
    ├── ScheduleServiceTests.swift
    ├── LiveActivityTests.swift       # Tests for Live Activity
    └── IntegrationTests.swift
```

---

## Architecture Overview

This section explains how the app is organized. Don't worry if you don't understand everything at first—refer back to this as you explore the code.

### The Big Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
│  (ContentView, NextTrainView, StationDetailView, etc.)          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       SCHEDULE SERVICE                          │
│  (The "brain" - manages all schedule data and state)            │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │  GTFS Parser │  │  PDF Parser  │  │   Bundled    │
    │  (Internet)  │  │  (Backup)    │  │   (Offline)  │
    └──────────────┘  └──────────────┘  └──────────────┘
```

### Design Pattern: MVVM-ish

This app loosely follows the **MVVM** (Model-View-ViewModel) pattern:

| Layer | What it does | Files |
|-------|--------------|-------|
| **Model** | Defines the shape of data | `GTFSModels.swift` |
| **View** | What the user sees | `ContentView.swift`, `NextTrainView.swift`, etc. |
| **ViewModel/Service** | Connects data to views | `ScheduleService.swift` |

### Data Sources (Priority Order)

The app tries to get schedule data from multiple sources:

1. **Live GTFS Data** (Best) - Downloaded from PATCO's website
2. **PDF Schedule** (Backup) - Parsed from PATCO's PDF timetables
3. **Bundled Data** (Always Available) - Built into the app

If #1 fails, it tries #2. If #2 fails, it uses #3. This ensures the app always works, even offline.

---

## How Data Flows

Let's trace what happens when a user opens the app:

### Step 1: App Launches

```
PATCOScheduleApp.swift
        │
        ▼
ContentView.swift creates ScheduleService
        │
        ▼
ScheduleService.init() immediately loads bundled data
```

**Why?** So the user sees something instantly, without waiting.

### Step 2: Background Data Fetch

```
ScheduleService.loadSchedule()
        │
        ▼
NetworkMonitor checks: "Is internet available?"
        │
        ├── NO  → Keep using bundled data
        │
        └── YES → Try to fetch live data
                    │
                    ▼
              GTFSParser.downloadAndParseGTFS()
                    │
                    ├── SUCCESS → Update scheduleData
                    │
                    └── FAIL → Try PDFScheduleParser
                                    │
                                    ├── SUCCESS → Update scheduleData
                                    │
                                    └── FAIL → Keep bundled data
```

### Step 3: User Selects a Station

```
User taps "Haddonfield" in StationPickerSheet
        │
        ▼
selectedStation is updated
        │
        ▼
NextTrainView receives the station
        │
        ▼
Calls scheduleService.getNextTrain(for: station, direction: .westbound)
        │
        ▼
ScheduleService filters stopTimes to find upcoming trains
        │
        ▼
UI displays "Next train in 5 minutes"
```

---

## Key Concepts Explained

### What is GTFS?

**GTFS** (General Transit Feed Specification) is a standard format for public transit schedules. It's a ZIP file containing CSV files:

- `stops.txt` - List of stations
- `trips.txt` - Individual train runs
- `stop_times.txt` - When each train arrives at each station
- `calendar.txt` - Which days each service runs

PATCO publishes their schedule in this format, and our app reads it.

### What is SwiftUI?

**SwiftUI** is Apple's modern way to build user interfaces. Instead of dragging buttons around, you write code that describes what you want:

```swift
// This creates a button that says "Hello"
Button("Hello") {
    print("Button tapped!")
}
```

### What is @Published and @StateObject?

These are SwiftUI tools for making the UI update automatically:

- **@Published**: "Hey SwiftUI, watch this variable. If it changes, update the screen."
- **@StateObject**: "This is the source of truth for my data. Keep it alive."
- **@EnvironmentObject**: "Pass this data down to child views automatically."

Example:
```swift
// In ScheduleService
@Published var loadState: ScheduleLoadState = .loading

// When loadState changes, any view watching it will update automatically
```

### What is async/await?

Modern Swift way to handle operations that take time (like downloading data):

```swift
// Old way (confusing nested callbacks)
downloadData { result in
    parseData(result) { parsed in
        updateUI(parsed)
    }
}

// New way (reads like normal code)
let result = await downloadData()
let parsed = await parseData(result)
updateUI(parsed)
```

### What is Optional (?)?

In Swift, a variable might or might not have a value. The `?` indicates "this might be nil":

```swift
var nextTrain: UpcomingTrain?  // Might be a train, might be nothing

// Safe way to use it:
if let train = nextTrain {
    print("Train arrives at \(train.departureTime)")
} else {
    print("No upcoming trains")
}
```

---

## Troubleshooting

### "No such module 'PATCOSchedule'" Error

This usually means Xcode hasn't finished indexing. Wait for the progress bar at the top to complete, or try:
1. Click Product → Clean Build Folder (Cmd + Shift + K)
2. Click Product → Build (Cmd + B)

### Simulator Won't Start

1. Try a different simulator from the dropdown
2. Go to Window → Devices and Simulators → Delete old simulators
3. Restart Xcode

### "Signing Requires a Development Team" Error

1. Click on the project in the left sidebar
2. Go to "Signing & Capabilities"
3. Sign in with your Apple ID under "Team"

### Build Succeeds but App Crashes

1. Look at the debug console at the bottom of Xcode
2. The red text shows what went wrong
3. Common fix: Clean and rebuild (Cmd + Shift + K, then Cmd + B)

### Changes Not Showing Up

1. Stop the app (Cmd + .)
2. Clean the build (Cmd + Shift + K)
3. Run again (Cmd + R)

---

## Running Tests

Tests verify the code works correctly. To run them:

1. Press `Cmd + U`, or
2. Click Product → Test

You'll see green checkmarks ✓ for passing tests or red X marks for failures.

---

## Making Changes

### Adding a New View

1. Right-click the `Views` folder
2. Click "New File..."
3. Choose "Swift File"
4. Name it `MyNewView.swift`
5. Add your SwiftUI code

### Modifying the Schedule

The bundled schedule is in `BundledScheduleData.swift`. You can:
- Update departure times in `weekdaySchedule` and `weekendSchedule`
- Add/remove stations in the `stops` array
- Adjust travel times in `travelTimesMinutes`

---

## iOS Live Activity (Lock Screen & Dynamic Island)

The app supports iOS Live Activity, which shows a countdown timer on your Lock Screen and in the Dynamic Island (on supported devices) so you can track your train without opening the app.

### What Is iOS Live Activity?

iOS Live Activity is a persistent notification that appears on your Lock Screen and Dynamic Island. Unlike regular notifications that disappear, a Live Activity stays visible and updates in real-time until you dismiss it or the train departs.

### How to Use Live Activity

1. **Select a station** and view upcoming trains
2. **Tap the "Track" button** on any train card
3. **The Live Activity appears** showing:
   - Station name and direction
   - Minutes until departure (updates automatically)
   - Destination
4. **View on Lock Screen** - See the countdown without unlocking your phone
5. **View in Dynamic Island** - On iPhone 14 Pro and later, see the countdown at the top of your screen
6. **Stop tracking** - Tap the "Stop Tracking" button in the app, or the Live Activity automatically ends when the train departs

### Requirements for Live Activity

- **iOS 16.1 or later** (Live Activity was introduced in iOS 16.1)
- **iPhone** (Live Activity is not available on iPad)
- **Dynamic Island** requires iPhone 14 Pro or later

### Architecture of Live Activity

iOS Live Activity uses Apple's **ActivityKit** framework and requires a **Widget Extension**:

```
┌─────────────────────────────────────────────────────────────────┐
│                         MAIN APP                                │
│  NextTrainView → LiveActivityManager → ActivityKit              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    WIDGET EXTENSION                             │
│  PATCOWidgets/PATCOLiveActivity.swift (UI for Lock Screen)     │
└─────────────────────────────────────────────────────────────────┘
```

### Key Files for Live Activity

| File | Purpose |
|------|---------|
| `PATCOActivityAttributes.swift` | Defines the data structure shared between app and widget |
| `LiveActivityManager.swift` | Starts, updates, and stops Live Activity |
| `PATCOWidgets/PATCOLiveActivity.swift` | The visual UI shown on Lock Screen and Dynamic Island |
| `PATCOWidgets/PATCOWidgetsBundle.swift` | Widget extension entry point |

### How Live Activity Updates Work

```
User taps "Track" on a train
        │
        ▼
LiveActivityManager.startActivity()
        │
        ▼
ActivityKit creates Lock Screen widget
        │
        ▼
Timer fires every 30 seconds
        │
        ▼
LiveActivityManager.updateActivity()
        │
        ▼
Lock Screen/Dynamic Island updates with new countdown
        │
        ▼
Train departs → LiveActivityManager.stopActivity()
```

### Testing Live Activity

**Important:** Live Activity cannot be tested in the Simulator. You must test on a physical device.

1. Build and run on a physical iPhone
2. Navigate to a station with upcoming trains
3. Tap "Track" on a train
4. Lock your phone and verify the Live Activity appears
5. Wait 30+ seconds and verify the countdown updates
6. Unlock and tap "Stop Tracking" to end

### Troubleshooting Live Activity

**"Track" button doesn't appear:**
- Ensure you're running iOS 16.1 or later
- Check that `NSSupportsLiveActivities` is set to `true` in Info.plist

**Live Activity doesn't start:**
- Check Settings → PATCO Schedule → Live Activity is enabled
- Some devices may have Live Activity disabled by default

**Live Activity doesn't update:**
- The app must remain installed (not deleted)
- Background App Refresh must be enabled

---

## Getting Help

- **Swift Documentation**: https://docs.swift.org
- **SwiftUI Tutorials**: https://developer.apple.com/tutorials/swiftui
- **GTFS Specification**: https://gtfs.org

---

## License

This project is for educational purposes. PATCO schedule data is publicly available from [ridepatco.org](https://www.ridepatco.org).
