import Foundation
import SwiftUI

// MARK: - TransitProvider Protocol

/// Protocol that any transit system must implement.
/// Adding a new transit system requires only a new conforming type — no core code changes.
protocol TransitProvider {
    var id: String { get }
    var displayName: String { get }   // e.g. "PATCO Schedule"
    var tagline: String { get }       // e.g. "South Jersey to Philadelphia"
    var systemIcon: String { get }    // SF Symbol name

    // Data Sources
    var gtfsURL: URL { get }
    var pdfScheduleURLs: [URL] { get }
    var schedulePage: URL? { get }
    var scheduleDomain: String { get }  // e.g. "https://www.ridepatco.org" for relative URL building

    // Stations & UI Groupings
    var stations: [Station] { get }
    var stationGroups: [StationGroup] { get }
    var directions: [TransitDirection] { get }

    // Direction Logic
    func matchesDirection(trip: GTFSTrip, direction: TransitDirection) -> Bool
    func findStation(matching stopName: String) -> Station?
    func isTerminus(station: Station, direction: TransitDirection) -> Bool

    // PDF Parsing Hints
    var pdfDirectionPatterns: [String: [String]] { get }  // e.g. ["westbound": ["to philadelphia", ...]]
    var pdfBundledStops: [GTFSStop] { get }
    var pdfCumulativeTravelTimes: [Int] { get }
    var pdfRouteId: String { get }
    var pdfWestboundHeadsign: String { get }
    var pdfEastboundHeadsign: String { get }

    // Bundled Fallback Schedule
    func generateBundledData() -> ScheduleData
}

// MARK: - TransitDirection

/// Replaces the hardcoded TrainDirection enum. Direction data is provider-supplied.
struct TransitDirection: Identifiable, Hashable {
    let id: String            // e.g. "westbound"
    let displayName: String   // e.g. "Westbound"
    let destination: String   // e.g. "15th-16th & Locust"
    let shortLabel: String    // e.g. "To Philly"
    let color: Color
    let directionId: Int?     // GTFS direction_id mapping
    let headsignPatterns: [String]  // lowercase substrings to match trip headsigns

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TransitDirection, rhs: TransitDirection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - StationGroup

/// Groups stations for sectioned UI display (e.g. "New Jersey" / "Philadelphia").
struct StationGroup: Identifiable {
    let id: String
    let name: String
    let stationIds: [String]
}
