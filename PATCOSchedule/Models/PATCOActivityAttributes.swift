import Foundation
import ActivityKit

/// Defines the data shown in the PATCO Live Activity
struct PATCOActivityAttributes: ActivityAttributes {

    /// Static data that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// Minutes until departure (updates as time passes)
        var minutesUntilDeparture: Int

        /// Formatted departure time (e.g., "10:42 AM")
        var departureTimeString: String

        /// Whether the train is arriving soon (< 5 minutes)
        var isArrivingSoon: Bool

        /// Timestamp of last update
        var lastUpdated: Date
    }

    /// Station name
    var stationName: String

    /// Direction of travel
    var direction: String

    /// Destination (e.g., "15th-16th & Locust" or "Lindenwold")
    var destination: String

    /// Trip ID for tracking
    var tripId: String

    /// Scheduled departure time
    var scheduledDeparture: Date
}

// MARK: - Helper Extensions

extension PATCOActivityAttributes.ContentState {
    /// Create content state from an UpcomingTrain
    static func from(train: UpcomingTrain) -> Self {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        return ContentState(
            minutesUntilDeparture: train.minutesUntilDeparture,
            departureTimeString: formatter.string(from: train.departureTime),
            isArrivingSoon: train.minutesUntilDeparture <= 5,
            lastUpdated: Date()
        )
    }
}
