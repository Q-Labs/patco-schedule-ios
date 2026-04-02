import Foundation
import ActivityKit

/// Defines the data shown in a transit Live Activity
@available(iOS 16.1, *)
public struct TransitActivityAttributes: ActivityAttributes {

    /// Dynamic data that updates during the activity
    public typealias ContentState = TransitActivityContentState

    /// Station name
    public var stationName: String

    /// Direction of travel
    public var direction: String

    /// Destination (e.g., "15th-16th & Locust" or "Lindenwold")
    public var destination: String

    /// Trip ID for tracking
    public var tripId: String

    /// Scheduled departure time
    public var scheduledDeparture: Date

    public init(stationName: String, direction: String, destination: String, tripId: String, scheduledDeparture: Date) {
        self.stationName = stationName
        self.direction = direction
        self.destination = destination
        self.tripId = tripId
        self.scheduledDeparture = scheduledDeparture
    }
}

/// Content state for a transit Live Activity (dynamic data that updates)
@available(iOS 16.1, *)
public struct TransitActivityContentState: Codable, Hashable {
    /// Minutes until departure (updates as time passes)
    public var minutesUntilDeparture: Int

    /// Seconds until departure (used when < 1 minute)
    public var secondsUntilDeparture: Int

    /// Formatted departure time (e.g., "10:42 AM")
    public var departureTimeString: String

    /// Whether the train is arriving soon (< 5 minutes)
    public var isArrivingSoon: Bool

    /// Whether to show seconds instead of minutes (< 1 minute remaining)
    public var showSeconds: Bool

    /// Whether the train has departed
    public var hasDeparted: Bool

    /// Timestamp of last update
    public var lastUpdated: Date

    public init(minutesUntilDeparture: Int, secondsUntilDeparture: Int = 0, departureTimeString: String, isArrivingSoon: Bool, showSeconds: Bool = false, hasDeparted: Bool = false, lastUpdated: Date) {
        self.minutesUntilDeparture = minutesUntilDeparture
        self.secondsUntilDeparture = secondsUntilDeparture
        self.departureTimeString = departureTimeString
        self.isArrivingSoon = isArrivingSoon
        self.showSeconds = showSeconds
        self.hasDeparted = hasDeparted
        self.lastUpdated = lastUpdated
    }
}
