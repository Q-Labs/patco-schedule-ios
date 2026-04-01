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

struct UpcomingTrain: Identifiable {
    let id = UUID()
    let departureTime: Date
    let arrivalTimeString: String
    let headsign: String
    let direction: TransitDirection
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
