import Foundation
import ActivityKit

// MARK: - ContentState Helper Extension

@available(iOS 16.1, *)
extension PATCOActivityAttributes.ContentState {
    /// Create content state from an UpcomingTrain
    static func from(train: UpcomingTrain) -> Self {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let now = Date()
        let timeInterval = train.departureTime.timeIntervalSince(now)
        let totalSeconds = max(0, Int(timeInterval))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        // Show seconds when under 1 minute
        let showSeconds = minutes == 0 && totalSeconds > 0
        let hasDeparted = totalSeconds <= 0

        return Self(
            minutesUntilDeparture: minutes,
            secondsUntilDeparture: showSeconds ? totalSeconds : seconds,
            departureTimeString: formatter.string(from: train.departureTime),
            isArrivingSoon: minutes <= 5,
            showSeconds: showSeconds,
            hasDeparted: hasDeparted,
            lastUpdated: now
        )
    }
}

/// Manages PATCO Live Activity for Lock Screen and Dynamic Island
@available(iOS 16.1, *)
@MainActor
class LiveActivityManager: ObservableObject {

    /// Current running activity
    @Published var currentActivity: Activity<PATCOActivityAttributes>?

    /// Whether Live Activities are supported on this device
    @Published var isSupported: Bool = false

    /// Whether an activity is currently running
    var isActivityRunning: Bool {
        currentActivity != nil
    }

    /// Timer for updating the activity
    private var updateTimer: Timer?

    /// Reference to schedule service for getting updated train times
    private weak var scheduleService: ScheduleService?

    /// Current station being tracked
    private var trackedStation: Station?

    /// Current direction being tracked
    private var trackedDirection: TransitDirection?

    /// Tracked departure time for the current train
    private var trackedDepartureTime: Date?

    init() {
        checkSupport()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Setup

    func setScheduleService(_ service: ScheduleService) {
        self.scheduleService = service
    }

    private func checkSupport() {
        isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Start Activity

    /// Start a Live Activity for a specific train
    func startActivity(
        station: Station,
        direction: TransitDirection,
        train: UpcomingTrain
    ) {
        guard isSupported else {
            print("Live Activities not supported on this device")
            return
        }

        // End any existing activity first
        if currentActivity != nil {
            Task {
                await endActivity()
            }
        }

        let attributes = PATCOActivityAttributes(
            stationName: station.displayName,
            direction: direction.displayName,
            destination: train.headsign,
            tripId: train.tripId,
            scheduledDeparture: train.departureTime
        )

        let initialState = PATCOActivityAttributes.ContentState.from(train: train)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: train.departureTime),
                pushType: nil // We'll use local updates, not push notifications
            )

            currentActivity = activity
            trackedStation = station
            trackedDirection = direction
            trackedDepartureTime = train.departureTime

            // Start timer to update the activity
            startUpdateTimer(for: train)

            print("Started Live Activity: \(activity.id)")

        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update Activity

    /// Update the Live Activity with new countdown
    func updateActivity() async {
        guard let activity = currentActivity,
              let trackedDepartureTime = trackedDepartureTime else {
            return
        }

        let now = Date()
        let timeInterval = trackedDepartureTime.timeIntervalSince(now)

        // Check if train has departed
        if timeInterval <= 0 {
            // Train has departed - dismiss the activity
            await endActivity()
            return
        }

        // Create updated state based on current time
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let showSeconds = minutes == 0

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let newState = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: minutes,
            secondsUntilDeparture: totalSeconds,
            departureTimeString: formatter.string(from: trackedDepartureTime),
            isArrivingSoon: minutes <= 5,
            showSeconds: showSeconds,
            hasDeparted: false,
            lastUpdated: now
        )

        await activity.update(
            ActivityContent(state: newState, staleDate: trackedDepartureTime)
        )

        // Adjust timer frequency based on time remaining
        adjustTimerIfNeeded(secondsRemaining: totalSeconds)
    }

    // MARK: - End Activity

    /// End the current Live Activity
    func endActivity() async {
        guard let activity = currentActivity else { return }

        updateTimer?.invalidate()
        updateTimer = nil

        // Create final state showing departed
        let finalState = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 0,
            secondsUntilDeparture: 0,
            departureTimeString: "--",
            isArrivingSoon: false,
            showSeconds: false,
            hasDeparted: true,
            lastUpdated: Date()
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        trackedStation = nil
        trackedDirection = nil
        trackedDepartureTime = nil

        print("Ended Live Activity")
    }

    // MARK: - Timer Management

    private func startUpdateTimer(for train: UpcomingTrain) {
        updateTimer?.invalidate()

        let timeRemaining = train.departureTime.timeIntervalSince(Date())
        let interval: TimeInterval = timeRemaining <= 60 ? 1 : 30

        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateActivity()
            }
        }
    }

    private func adjustTimerIfNeeded(secondsRemaining: Int) {
        // Switch to 1-second updates when under 1 minute
        if secondsRemaining <= 60 && secondsRemaining > 0 {
            // Check if we need to speed up the timer
            if let timer = updateTimer, timer.timeInterval > 1 {
                updateTimer?.invalidate()
                updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.updateActivity()
                    }
                }
            }
        }
    }

    // MARK: - Cleanup

    /// End all active Live Activities (useful on app termination)
    func endAllActivities() async {
        for activity in Activity<PATCOActivityAttributes>.activities {
            let finalState = PATCOActivityAttributes.ContentState(
                minutesUntilDeparture: 0,
                secondsUntilDeparture: 0,
                departureTimeString: "--",
                isArrivingSoon: false,
                showSeconds: false,
                hasDeparted: true,
                lastUpdated: Date()
            )

            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        currentActivity = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
