import Foundation
import ActivityKit

/// Manages PATCO Live Activities for Lock Screen and Dynamic Island
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
    private var trackedDirection: TrainDirection?

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
        if #available(iOS 16.1, *) {
            isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
        } else {
            isSupported = false
        }
    }

    // MARK: - Start Activity

    /// Start a Live Activity for a specific train
    func startActivity(
        station: Station,
        direction: TrainDirection,
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
            direction: direction == .westbound ? "Westbound" : "Eastbound",
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

            // Start timer to update the activity
            startUpdateTimer()

            print("Started Live Activity: \(activity.id)")

        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update Activity

    /// Update the Live Activity with new countdown
    func updateActivity() async {
        guard let activity = currentActivity,
              let station = trackedStation,
              let direction = trackedDirection,
              let scheduleService = scheduleService else {
            return
        }

        // Get the latest train info
        guard let nextTrain = scheduleService.getNextTrain(for: station, direction: direction) else {
            // No more trains - end the activity
            await endActivity()
            return
        }

        // Check if the train has departed
        if nextTrain.departureTime <= Date() {
            // Train departed - check for next train
            let upcomingTrains = scheduleService.getUpcomingTrains(for: station, direction: direction, limit: 2)
            if upcomingTrains.count > 1 {
                // Show next train
                let newState = PATCOActivityAttributes.ContentState.from(train: upcomingTrains[1])
                await activity.update(
                    ActivityContent(state: newState, staleDate: upcomingTrains[1].departureTime)
                )
            } else {
                // No more trains
                await endActivity()
            }
            return
        }

        // Update with current countdown
        let newState = PATCOActivityAttributes.ContentState.from(train: nextTrain)

        await activity.update(
            ActivityContent(state: newState, staleDate: nextTrain.departureTime)
        )
    }

    // MARK: - End Activity

    /// End the current Live Activity
    func endActivity() async {
        guard let activity = currentActivity else { return }

        updateTimer?.invalidate()
        updateTimer = nil

        // Create final state
        let finalState = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 0,
            departureTimeString: "--",
            isArrivingSoon: false,
            lastUpdated: Date()
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        trackedStation = nil
        trackedDirection = nil

        print("Ended Live Activity")
    }

    // MARK: - Timer Management

    private func startUpdateTimer() {
        updateTimer?.invalidate()

        // Update every 30 seconds to match the main app
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateActivity()
            }
        }
    }

    // MARK: - Cleanup

    /// End all active Live Activities (useful on app termination)
    func endAllActivities() async {
        for activity in Activity<PATCOActivityAttributes>.activities {
            let finalState = PATCOActivityAttributes.ContentState(
                minutesUntilDeparture: 0,
                departureTimeString: "--",
                isArrivingSoon: false,
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
