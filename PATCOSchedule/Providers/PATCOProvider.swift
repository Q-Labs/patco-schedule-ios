import Foundation
import SwiftUI

/// PATCO Speedline transit provider.
/// All PATCO-specific data lives here — stations, directions, URLs, bundled schedule.
struct PATCOProvider: TransitProvider {

    // MARK: - Identity

    let id = "patco"
    let displayName = "PATCO Schedule"
    let tagline = "South Jersey to Philadelphia"
    let systemIcon = "tram.fill"

    // MARK: - Data Sources

    let gtfsURL = URL(string: "https://www.ridepatco.org/developers/PortAuthorityTransitCorporation.zip")!
    let schedulePage: URL? = URL(string: "https://www.ridepatco.org/schedules/")
    let scheduleDomain = "https://www.ridepatco.org"

    var pdfScheduleURLs: [URL] {
        [
            "https://www.ridepatco.org/schedules/schedules-background.pdf",
            "https://www.ridepatco.org/schedules/patco-schedule.pdf",
            "https://www.ridepatco.org/schedules/timetable.pdf"
        ].compactMap { URL(string: $0) }
    }

    // MARK: - Stations

    let stations: [Station] = [
        Station(id: "LINDENWOLD", name: "Lindenwold",          displayName: "Lindenwold",        order: 0),
        Station(id: "ASHLAND",    name: "Ashland",              displayName: "Ashland",           order: 1),
        Station(id: "WOODCREST",  name: "Woodcrest",            displayName: "Woodcrest",         order: 2),
        Station(id: "HADDONFIELD",name: "Haddonfield",          displayName: "Haddonfield",       order: 3),
        Station(id: "WESTMONT",   name: "Westmont",             displayName: "Westmont",          order: 4),
        Station(id: "COLLINGSWOOD",name: "Collingswood",        displayName: "Collingswood",      order: 5),
        Station(id: "FERRY",      name: "Ferry Avenue",         displayName: "Ferry Ave",         order: 6),
        Station(id: "BROADWAY",   name: "Broadway",             displayName: "Broadway",          order: 7),
        Station(id: "CITYHALL",   name: "City Hall",            displayName: "City Hall",         order: 8),
        Station(id: "FRANKLIN",   name: "Franklin Square",      displayName: "Franklin Square",   order: 9),
        Station(id: "8TH",        name: "8th and Market",       displayName: "8th & Market",      order: 10),
        Station(id: "9-10TH",     name: "9-10th and Locust",    displayName: "9th-10th & Locust", order: 11),
        Station(id: "12-13TH",    name: "12-13th and Locust",   displayName: "12th-13th & Locust",order: 12),
        Station(id: "15-16TH",    name: "15-16th and Locust",   displayName: "15th-16th & Locust",order: 13)
    ]

    // MARK: - Directions

    let directions: [TransitDirection] = [
        TransitDirection(
            id: "westbound",
            displayName: "Westbound",
            destination: "15th-16th & Locust",
            shortLabel: "To Philly",
            color: .purple,
            directionId: 0,
            headsignPatterns: ["15", "16", "locust", "westbound", "philadelphia"]
        ),
        TransitDirection(
            id: "eastbound",
            displayName: "Eastbound",
            destination: "Lindenwold",
            shortLabel: "To NJ",
            color: .green,
            directionId: 1,
            headsignPatterns: ["lindenwold", "eastbound"]
        )
    ]

    // MARK: - Station Groups

    let stationGroups: [StationGroup] = [
        StationGroup(
            id: "nj",
            name: "New Jersey",
            stationIds: ["LINDENWOLD", "ASHLAND", "WOODCREST", "HADDONFIELD",
                         "WESTMONT", "COLLINGSWOOD", "FERRY", "BROADWAY", "CITYHALL"]
        ),
        StationGroup(
            id: "philadelphia",
            name: "Philadelphia",
            stationIds: ["FRANKLIN", "8TH", "9-10TH", "12-13TH", "15-16TH"]
        )
    ]

    // MARK: - Direction Logic

    func matchesDirection(trip: GTFSTrip, direction: TransitDirection) -> Bool {
        if let headsign = trip.headsign?.lowercased() {
            for pattern in direction.headsignPatterns {
                if headsign.contains(pattern) { return true }
            }
        }
        if let dirId = trip.directionId, let expected = direction.directionId {
            return dirId == expected
        }
        return true
    }

    func findStation(matching stopName: String) -> Station? {
        let normalized = stopName.lowercased()
        return stations.first { station in
            normalized.contains(station.name.lowercased()) ||
            station.name.lowercased().contains(normalized) ||
            normalized.contains(station.id.lowercased())
        }
    }

    func isTerminus(station: Station, direction: TransitDirection) -> Bool {
        switch direction.id {
        case "eastbound":  return station.order == 0   // Lindenwold — origin for eastbound
        case "westbound":  return station.order == 13  // 15th-16th — origin for westbound
        default:           return false
        }
    }

    // MARK: - PDF Parsing Hints

    let pdfDirectionPatterns: [String: [String]] = [
        "westbound": ["to philadelphia", "westbound", "to 15", "to locust"],
        "eastbound": ["to lindenwold", "eastbound", "to new jersey"]
    ]

    var pdfBundledStops: [GTFSStop] { PATCOBundledScheduleData.stops }
    var pdfCumulativeTravelTimes: [Int] { PATCOBundledScheduleData.cumulativeTravelTimes }
    let pdfRouteId = "PATCO"
    let pdfWestboundHeadsign = "15th-16th & Locust"
    let pdfEastboundHeadsign = "Lindenwold"

    // MARK: - Bundled Fallback

    func generateBundledData() -> ScheduleData {
        PATCOBundledScheduleData.generateScheduleData()
    }
}
