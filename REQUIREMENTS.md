# PATCO Schedule iOS App - Requirements Specification

## Overview

The PATCO Schedule iOS App is a native iOS application that provides real-time train schedule information for the PATCO Speedline transit system, which runs between Lindenwold, New Jersey and Philadelphia, Pennsylvania. The app operates primarily offline using bundled schedule data while automatically fetching live updates when network connectivity is available.

**Target Minimum iOS Version:** iOS 17.0
**Supported Platforms:** iPhone and iPad
**Live Activity Support:** iOS 16.1+

---

## 1. Core Features

### 1.1 Main User Interface Screens

#### A. Welcome Screen
- Shown when app is first launched with no station selected
- Displays app title "PATCO Schedule" with train icon
- Descriptive text about the service
- Call-to-action button to "Select Your Station"
- Persists only until user selects a station

#### B. Main Schedule View (Three-Tab Navigation)

**Tab 1: Next Train View**
- Displays next upcoming train in both directions from selected station
- Shows large countdown in minutes (48pt bold rounded font)
- Color-coded by urgency:
  - Green: >5 minutes remaining
  - Orange: 2-5 minutes remaining
  - Red: <2 minutes remaining
- For trains under 1 minute: switches to seconds countdown in red
- Displays formatted departure time (e.g., "10:42 AM")
- Shows destination (e.g., "15th-16th & Locust" or "Lindenwold")
- "Track" button to start Live Activity (iOS 16.1+)
- Shows data source indicator (Live GTFS, PDF, or Bundled)
- Manual refresh pull-down capability
- Auto-refreshes every 30 seconds
- Displays last updated timestamp

**Tab 2: Schedule View (Station Detail)**
- Full list of upcoming trains from selected station
- Segmented picker to switch between directions:
  - Westbound (to Philadelphia)
  - Eastbound (to New Jersey)
- Shows up to 10 upcoming trains
- Each train row displays:
  - Minutes until departure (color-coded)
  - Headsign/destination
  - Formatted departure time
  - Direction arrow indicator
- Empty state handling for stations with no upcoming service
- Manual refresh button in navigation bar
- Auto-refreshes every 30 seconds

**Tab 3: All Stations View**
- Browse-all feature showing all 14 PATCO stations
- Stations grouped by geography:
  - New Jersey section (Lindenwold through City Hall)
  - Philadelphia section (Franklin Square through 15th-16th & Locust)
- Each station row shows:
  - Station name
  - Next train to Philadelphia with "Philly" label (with minutes if available)
  - Next train to New Jersey with "Lindenwold" label (with minutes if available)
- Tap to navigate to that station's detail schedule

#### C. Station Picker Sheet
- Modal overlay for selecting/changing station
- Searchable list of all 14 stations
- Grouped by geography (New Jersey/Philadelphia)
- Display both short names (e.g., "Ferry Ave") and full names (e.g., "Ferry Avenue")
- Checkmark indicator for currently selected station
- Persists selected station in UserDefaults
- Searches by both display name and full name

#### D. Loading/State Screens
- **Loading State:** Shows animated train icon with pulse effect + progress spinner
- **Retrying State:** Shows "Retrying..." with attempt counter (e.g., "Attempt 1 of 2")
- **Network Waiting State:** Shows WiFi off icon, explains waiting for connection, displays connection tips
- **Error State:** Shows warning icon, displays error message, "Try Again" button with troubleshooting tips
- **No Data State:** When schedule data is unavailable, offers to retry

---

## 2. Data Models

### 2.1 GTFS (General Transit Feed Specification) Models

**GTFSStop**
- `id`: String (stop identifier, e.g., "LINDENWOLD")
- `name`: String (full station name)
- `latitude`: Double? (GPS latitude, nullable)
- `longitude`: Double? (GPS longitude, nullable)

**GTFSRoute**
- `id`: String (route identifier, e.g., "PATCO")
- `shortName`: String (short route name)
- `longName`: String (full route name)
- `type`: Int (GTFS route type)
- `color`: String? (hex color for route)
- `textColor`: String? (hex color for text)

**GTFSTrip**
- `id`: String (unique trip identifier)
- `routeId`: String (route this trip belongs to)
- `serviceId`: String (service type: WEEKDAY, SATURDAY, SUNDAY)
- `headsign`: String? (destination display text)
- `directionId`: Int? (0=westbound/Philadelphia, 1=eastbound/New Jersey)

**GTFSStopTime**
- `tripId`: String (which trip this belongs to)
- `arrivalTime`: String (HH:MM:SS format)
- `departureTime`: String (HH:MM:SS format)
- `stopId`: String (which stop)
- `stopSequence`: Int (order of this stop in trip)

**GTFSCalendar**
- `serviceId`: String (identifies service type)
- `monday` through `sunday`: Int (1=active, 0=inactive)
- `startDate`: String (YYYYMMDD format)
- `endDate`: String (YYYYMMDD format)
- Function: `isActiveOn(weekday: Int) -> Bool`

**GTFSCalendarDate**
- `serviceId`: String (service to modify)
- `date`: String (YYYYMMDD format)
- `exceptionType`: Int (1=add service, 2=remove service)

### 2.2 Application-Specific Models

**TrainDirection** (Enum)
- `.eastbound` - "Eastbound" (destination: "Lindenwold")
- `.westbound` - "Westbound" (destination: "15th-16th & Locust")

**UpcomingTrain**
- `id`: UUID
- `departureTime`: Date
- `arrivalTimeString`: String
- `headsign`: String
- `direction`: TrainDirection
- `tripId`: String
- Computed: `minutesUntilDeparture`, `formattedDepartureTime`

**Station**
- `id`: String (GTFS stop ID match)
- `name`: String (full name)
- `displayName`: String (short name for UI)
- `order`: Int (0-13, position along line)

**14 PATCO Stations (in order):**
1. Lindenwold (NJ terminus)
2. Ashland
3. Woodcrest
4. Haddonfield
5. Westmont
6. Collingswood
7. Ferry Avenue
8. Broadway
9. City Hall
10. Franklin Square (Delaware River crossing)
11. 8th and Market
12. 9-10th and Locust
13. 12-13th and Locust
14. 15-16th and Locust (PA terminus)

**ScheduleLoadState** (Enum)
- `.notLoaded` - No data loaded yet
- `.loading` - Currently fetching data
- `.retrying(attempt: Int, maxAttempts: Int)` - Retrying after failure
- `.waitingForNetwork` - No internet, waiting to try
- `.loaded(source: DataSource)` - Successfully loaded
- `.error(message: String)` - Failed to load

**DataSource Options:**
- `.bundled` - Built-in schedule data
- `.live` - Live GTFS data from PATCO
- `.pdf` - Parsed from PDF schedule
- `.special` - Special schedule (holidays, etc.)

---

## 3. Services & Architecture

### 3.1 ScheduleService (Main Orchestrator)

**Purpose:** Central service managing all schedule data, loading states, and train queries

**Key Methods:**
- `loadSchedule() async` - Load schedule (tries bundled first, then live sources)
- `refreshFromLive() async` - Force refresh from online sources
- `checkForUpdates() async -> Bool` - Check if updates available
- `getUpcomingTrains(for station, direction, limit) -> [UpcomingTrain]`
- `getNextTrain(for station, direction) -> UpcomingTrain?`

**Logic:**
1. Initialization: Immediately loads bundled data
2. Background loading: Starts timer to fetch best available data
3. Network monitoring: Automatically retries when connection restored
4. Retry strategy: Maximum 2 retry attempts with 2-second delay
5. Fallback chain: Live GTFS → PDF → Bundled (always succeeds)

**Direction Matching:**
- Westbound: Headsign contains "15", "16", "Locust", or "Philadelphia", OR directionId == 0
- Eastbound: Headsign contains "Lindenwold" OR directionId == 1

### 3.2 GTFSParser (Live Data Source)

**Purpose:** Downloads and parses GTFS ZIP from PATCO's official endpoint

**GTFS Source URL:**
```
https://www.ridepatco.org/developers/PortAuthorityTransitCorporation.zip
```

**Key Features:**
- Downloads GTFS ZIP and extracts to app's cache directory
- Smart caching: 24-hour cache with update checks
- Pure Swift ZIP parsing (no external dependencies)
- Parses: stops.txt, routes.txt, trips.txt, stop_times.txt, calendar.txt, calendar_dates.txt

### 3.3 PDFScheduleParser (Backup & Special Schedules)

**Purpose:** Parse schedule PDF timetables as fallback and detect special schedules

**Known Schedule URLs:**
- Weekday: `https://www.ridepatco.org/schedules/schedules-background.pdf`
- Weekend: `https://www.ridepatco.org/schedules/schedules-weekend.pdf`

**Special Schedule Detection:**
- Scrapes PATCO schedule page HTML
- Looks for keywords: "holiday schedule", "special schedule", "modified schedule"
- Extracts PDF links and effective dates

### 3.4 BundledScheduleData (Always Available)

**Purpose:** Provide offline schedule data bundled with app

**Travel Times (cumulative from Lindenwold):**
- Lindenwold → Ashland: 3 min
- → Woodcrest: 5 min
- → Haddonfield: 8 min
- → Westmont: 10 min
- → Collingswood: 12 min
- → Ferry Ave: 14 min
- → Broadway: 17 min
- → City Hall: 19 min
- → Franklin Square: 21 min
- → 8th & Market: 23 min
- → 9-10th & Locust: 25 min
- → 12-13th & Locust: 26 min
- → 15-16th & Locust: 27 min

**Generated Schedules:**
- Weekday: ~140+ trains per direction (frequent during rush hours)
- Weekend: ~70 trains per direction (50% of weekday frequency)

### 3.5 NetworkMonitor (Connectivity Intelligence)

**Network Status:**
- `.unknown` - Not yet determined
- `.disconnected` - No internet
- `.connected(quality: ConnectionQuality)`

**Connection Quality:**
- `.poor` - Constrained network or weak cellular
- `.moderate` - Cellular or slow WiFi
- `.good` - Strong WiFi or ethernet

**Auto-refresh:** Triggers data refresh when connection restored

---

## 4. iOS Live Activity & Widget Functionality

### 4.1 Live Activity Overview

**Purpose:** Show real-time train countdown on iOS Lock Screen and Dynamic Island

**Requirements:**
- iOS 16.1+ (ActivityKit)
- iPhone only (not iPad)
- Dynamic Island on iPhone 14 Pro+

### 4.2 PATCOActivityAttributes

**Static Attributes:**
- `stationName`: String
- `direction`: String
- `destination`: String
- `tripId`: String
- `scheduledDeparture`: Date

**Dynamic Content State:**
- `minutesUntilDeparture`: Int
- `secondsUntilDeparture`: Int
- `departureTimeString`: String
- `isArrivingSoon`: Bool (≤5 minutes)
- `showSeconds`: Bool (<1 minute)
- `hasDeparted`: Bool
- `lastUpdated`: Date

### 4.3 LiveActivityManager

**Behavior:**
- Creates new Live Activity when user taps "Track"
- Updates every 30 seconds normally
- Switches to 1-second updates when <1 minute remaining
- Auto-dismisses when departure time passed
- Shows seconds countdown in red when <1 minute

### 4.4 Live Activity UI

**Lock Screen View:**
```
┌─────────────────────────────────┐
│ 🚊 Haddonfield                  │
│ ← to 15th-16th & Locust     12  │
│ Departs at 10:42 AM         min │
└─────────────────────────────────┘
```

**Dynamic Island (Expanded):**
```
┌────────────────────────────────┐
│ 🚊 Haddonfield │ 12 min        │
│ Westbound to 15-16 & Locust    │
│ Departs at 10:42 AM            │
└────────────────────────────────┘
```

**Dynamic Island (Compact):**
```
[🚊] [12m] or [🔴 45s]
```

---

## 5. Special Features & Edge Cases

### 5.1 Franklin Square (River Crossing)
- Station 10 crosses the Delaware River from NJ to PA
- Explicitly noted in code comments

### 5.2 Terminus Stations
- Lindenwold: No eastbound departures (origin station)
- 15-16th & Locust: No westbound departures (origin station)
- UI shows "Trains originate here" for unavailable direction

### 5.3 Service Calendar Exceptions
- Checks calendar_dates.txt for specific date overrides
- Exception type 1: Add service
- Exception type 2: Remove service

### 5.4 Time Handling
- Supports GTFS times >= 24:00 (overnight service)
- Past trains filtered from results
- <1 minute shows seconds in red

### 5.5 Station Fuzzy Matching
- Exact match on station ID
- Contains matching on station name
- Case-insensitive
- Substring matching fallback

### 5.6 Network Status & Refresh Strategy
- Bundled data loaded immediately
- 6-hour background check timer
- HEAD request for lightweight update check
- Only downloads if remote is newer
- Auto-retry on network restore

---

## 6. User State Persistence

**Selected Station:**
- Stored in UserDefaults with key "savedStationId"
- Automatically saved on selection
- Restored on app relaunch
- First launch shows welcome screen if no saved station

---

## 7. Data Sources Priority & Fallback

```
1. IMMEDIATE: Load bundled data
   └─ User sees content instantly

2. BACKGROUND: Check for live updates
   ├─ No network: Use bundled, set "waiting" state
   │
   ├─ Try Live GTFS
   │  ├─ Success: Use live data
   │  └─ Failure: Continue
   │
   ├─ Try PDF Schedule
   │  ├─ Success: Use PDF data
   │  └─ Failure: Continue
   │
   └─ Fall back to bundled (always succeeds)
```

---

## 8. Testing Coverage

### Unit Tests

**GTFSModelsTests (~55 assertions):**
- JSON decoding for all GTFS models
- Optional field handling
- Calendar service day checking
- Station finding and matching

**BundledScheduleDataTests (~70 assertions):**
- 14 stations with valid coordinates
- Travel times validation
- 3 service calendars
- Rush hour frequency verification
- Data consistency checks

**ScheduleServiceTests (~20 assertions):**
- Initialization loads bundled data
- `getUpcomingTrains()` functionality
- Direction and limit parameters
- Terminal station handling
- Performance: 100 queries benchmark

**LiveActivityTests (~40 assertions):**
- Attributes creation
- ContentState validation
- ArrivingSoon and ShowSeconds flags
- Codable/Hashable conformance

**IntegrationTests (~35 assertions):**
- Full schedule load and query
- Trip ordering validation
- Service calendar correctness
- Concurrent query handling
- Data integrity verification

---

## 9. System Requirements & Configuration

### 9.1 Requirements
- iOS 17.0 minimum
- iPhone and iPad support
- arm64 architecture

### 9.2 Orientation Support
- iPhone: Portrait, Landscape Left, Landscape Right
- iPad: All orientations including Upside-Down

### 9.3 Network Configuration
- HTTPS required (ATS enforced)
- Exception for ridepatco.org domain

### 9.4 Capabilities
- Live Activities enabled (NSSupportsLiveActivities)
- Background Fetch enabled

### 9.5 Privacy
- No sensitive data collection
- No analytics or user tracking
- Only UserDefaults for station preference

---

## 10. Error Handling & Recovery

### Network Errors
- GTFS download fails → Try PDF → Fall back to bundled
- Shows error message with "Try Again" button
- Auto-retry on network restore

### Data Format Errors
- ZIP extraction: Skips unsupported formats, returns partial data
- CSV parsing: Skips malformed rows
- Time parsing: Ignores unparseable times

### State Recovery
- Always has bundled data as fallback
- Keeps previous cached data if refresh fails

---

## 11. Performance Considerations

### Query Performance
- In-memory filtering on loaded data
- O(1) lookups for service/stop IDs
- 100 consecutive queries tested

### Memory Management
- ~840 trips × 14 stops = ~12K stop times per service
- Total parsed data < 50MB
- Cached in Caches directory (OS can clean)

### Update Efficiency
- 6-hour check timer with lightweight HEAD request
- Only downloads if remote is newer

---

## 12. Summary of Key Features

- Real-time countdown with color-coded urgency
- Multiple data sources with intelligent fallback (Live GTFS → PDF → Bundled)
- Offline capability with bundled schedule
- Smart caching with update detection
- iOS Live Activity on Lock Screen and Dynamic Island
- Station persistence across app launches
- Network monitoring with automatic retry
- Special schedule detection for holidays
- All 14 PATCO stations with geographic grouping
- Both directions (Westbound/Eastbound) support
- Fuzzy station matching
- Comprehensive test coverage (200+ assertions)
- No user tracking or unnecessary permissions
