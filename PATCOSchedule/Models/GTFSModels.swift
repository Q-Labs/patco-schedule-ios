import Foundation

// MARK: - GTFS Data Models

struct GTFSStop: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id = "stop_id"
        case name = "stop_name"
        case latitude = "stop_lat"
        case longitude = "stop_lon"
    }
}

struct GTFSRoute: Identifiable, Codable {
    let id: String
    let shortName: String
    let longName: String
    let type: Int
    let color: String?
    let textColor: String?

    enum CodingKeys: String, CodingKey {
        case id = "route_id"
        case shortName = "route_short_name"
        case longName = "route_long_name"
        case type = "route_type"
        case color = "route_color"
        case textColor = "route_text_color"
    }
}

struct GTFSTrip: Identifiable, Codable {
    let id: String
    let routeId: String
    let serviceId: String
    let headsign: String?
    let directionId: Int?

    enum CodingKeys: String, CodingKey {
        case id = "trip_id"
        case routeId = "route_id"
        case serviceId = "service_id"
        case headsign = "trip_headsign"
        case directionId = "direction_id"
    }
}

struct GTFSStopTime: Codable {
    let tripId: String
    let arrivalTime: String
    let departureTime: String
    let stopId: String
    let stopSequence: Int

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case stopId = "stop_id"
        case stopSequence = "stop_sequence"
    }
}

struct GTFSCalendar: Codable {
    let serviceId: String
    let monday: Int
    let tuesday: Int
    let wednesday: Int
    let thursday: Int
    let friday: Int
    let saturday: Int
    let sunday: Int
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday
        case startDate = "start_date"
        case endDate = "end_date"
    }

    func isActiveOn(weekday: Int) -> Bool {
        switch weekday {
        case 1: return sunday == 1
        case 2: return monday == 1
        case 3: return tuesday == 1
        case 4: return wednesday == 1
        case 5: return thursday == 1
        case 6: return friday == 1
        case 7: return saturday == 1
        default: return false
        }
    }
}

struct GTFSCalendarDate: Codable {
    let serviceId: String
    let date: String
    let exceptionType: Int

    enum CodingKeys: String, CodingKey {
        case serviceId = "service_id"
        case date
        case exceptionType = "exception_type"
    }
}

// MARK: - App-Specific Models

enum TrainDirection: String, CaseIterable, Identifiable {
    case eastbound = "Eastbound"
    case westbound = "Westbound"

    var id: String { rawValue }

    var destination: String {
        switch self {
        case .eastbound: return "Lindenwold"
        case .westbound: return "15th-16th & Locust"
        }
    }
}

struct UpcomingTrain: Identifiable {
    let id = UUID()
    let departureTime: Date
    let arrivalTimeString: String
    let headsign: String
    let direction: TrainDirection
    let tripId: String

    var minutesUntilDeparture: Int {
        let interval = departureTime.timeIntervalSince(Date())
        return max(0, Int(interval / 60))
    }

    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: departureTime)
    }
}

struct Station: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let order: Int

    static let allStations: [Station] = [
        Station(id: "LINDENWOLD", name: "Lindenwold", displayName: "Lindenwold", order: 0),
        Station(id: "ASHLAND", name: "Ashland", displayName: "Ashland", order: 1),
        Station(id: "WOODCREST", name: "Woodcrest", displayName: "Woodcrest", order: 2),
        Station(id: "HADDONFIELD", name: "Haddonfield", displayName: "Haddonfield", order: 3),
        Station(id: "WESTMONT", name: "Westmont", displayName: "Westmont", order: 4),
        Station(id: "COLLINGSWOOD", name: "Collingswood", displayName: "Collingswood", order: 5),
        Station(id: "FERRY", name: "Ferry Avenue", displayName: "Ferry Ave", order: 6),
        Station(id: "BROADWAY", name: "Broadway", displayName: "Broadway", order: 7),
        Station(id: "CITYHALL", name: "City Hall", displayName: "City Hall", order: 8),
        Station(id: "FRANKLIN", name: "Franklin Square", displayName: "Franklin Square", order: 9),
        Station(id: "8TH", name: "8th and Market", displayName: "8th & Market", order: 10),
        Station(id: "9-10TH", name: "9-10th and Locust", displayName: "9th-10th & Locust", order: 11),
        Station(id: "12-13TH", name: "12-13th and Locust", displayName: "12th-13th & Locust", order: 12),
        Station(id: "15-16TH", name: "15-16th and Locust", displayName: "15th-16th & Locust", order: 13)
    ]

    static func findStation(matching stopName: String) -> Station? {
        let normalizedName = stopName.lowercased()
        return allStations.first { station in
            normalizedName.contains(station.name.lowercased()) ||
            station.name.lowercased().contains(normalizedName) ||
            normalizedName.contains(station.id.lowercased())
        }
    }
}

// MARK: - Schedule Data Container

struct ScheduleData {
    var stops: [GTFSStop] = []
    var routes: [GTFSRoute] = []
    var trips: [GTFSTrip] = []
    var stopTimes: [GTFSStopTime] = []
    var calendars: [GTFSCalendar] = []
    var calendarDates: [GTFSCalendarDate] = []

    var isLoaded: Bool {
        !stops.isEmpty && !trips.isEmpty && !stopTimes.isEmpty
    }
}
