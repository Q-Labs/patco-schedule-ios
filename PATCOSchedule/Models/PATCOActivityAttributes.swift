import Foundation
import ActivityKit

/// Defines the data shown in the PATCO Live Activity
@available(iOS 16.1, *)
public struct PATCOActivityAttributes: ActivityAttributes {

    /// Dynamic data that updates during the activity
    public typealias ContentState = PATCOActivityContentState

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

/// Content state for the PATCO Live Activity (dynamic data that updates)
@available(iOS 16.1, *)
public struct PATCOActivityContentState: Codable, Hashable {
    /// Minutes until departure (updates as time passes)
    public var minutesUntilDeparture: Int

    /// Formatted departure time (e.g., "10:42 AM")
    public var departureTimeString: String

    /// Whether the train is arriving soon (< 5 minutes)
    public var isArrivingSoon: Bool

    /// Timestamp of last update
    public var lastUpdated: Date

    public init(minutesUntilDeparture: Int, departureTimeString: String, isArrivingSoon: Bool, lastUpdated: Date) {
        self.minutesUntilDeparture = minutesUntilDeparture
        self.departureTimeString = departureTimeString
        self.isArrivingSoon = isArrivingSoon
        self.lastUpdated = lastUpdated
    }
}
