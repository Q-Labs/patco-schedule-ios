import Foundation

/// Bundled PATCO schedule data based on published timetables
/// This serves as the primary data source, with GTFS updates fetched periodically
struct BundledScheduleData {

    // MARK: - Station Data

    static let stops: [GTFSStop] = [
        GTFSStop(id: "LINDENWOLD", name: "Lindenwold", latitude: 39.8249, longitude: -74.9830),
        GTFSStop(id: "ASHLAND", name: "Ashland", latitude: 39.8631, longitude: -75.0061),
        GTFSStop(id: "WOODCREST", name: "Woodcrest", latitude: 39.8742, longitude: -75.0178),
        GTFSStop(id: "HADDONFIELD", name: "Haddonfield", latitude: 39.8916, longitude: -75.0378),
        GTFSStop(id: "WESTMONT", name: "Westmont", latitude: 39.9068, longitude: -75.0533),
        GTFSStop(id: "COLLINGSWOOD", name: "Collingswood", latitude: 39.9176, longitude: -75.0678),
        GTFSStop(id: "FERRY", name: "Ferry Avenue", latitude: 39.9266, longitude: -75.0815),
        GTFSStop(id: "BROADWAY", name: "Broadway", latitude: 39.9405, longitude: -75.1056),
        GTFSStop(id: "CITYHALL", name: "City Hall", latitude: 39.9490, longitude: -75.1205),
        GTFSStop(id: "FRANKLIN", name: "Franklin Square", latitude: 39.9534, longitude: -75.1504),
        GTFSStop(id: "8TH", name: "8th and Market", latitude: 39.9527, longitude: -75.1534),
        GTFSStop(id: "9-10TH", name: "9-10th and Locust", latitude: 39.9479, longitude: -75.1573),
        GTFSStop(id: "12-13TH", name: "12-13th and Locust", latitude: 39.9479, longitude: -75.1637),
        GTFSStop(id: "15-16TH", name: "15-16th and Locust", latitude: 39.9479, longitude: -75.1677)
    ]

    // Travel times between stations (in minutes) - westbound direction
    // Eastbound uses the same times in reverse
    static let travelTimesMinutes: [Int] = [
        0,  // Lindenwold (start)
        3,  // Lindenwold -> Ashland
        2,  // Ashland -> Woodcrest
        3,  // Woodcrest -> Haddonfield
        2,  // Haddonfield -> Westmont
        2,  // Westmont -> Collingswood
        2,  // Collingswood -> Ferry Avenue
        3,  // Ferry Avenue -> Broadway
        2,  // Broadway -> City Hall
        2,  // City Hall -> Franklin Square (crosses river)
        2,  // Franklin Square -> 8th and Market
        2,  // 8th and Market -> 9-10th and Locust
        1,  // 9-10th -> 12-13th and Locust
        1   // 12-13th -> 15-16th and Locust
    ]

    // Cumulative travel times from Lindenwold
    static var cumulativeTravelTimes: [Int] {
        var cumulative: [Int] = []
        var total = 0
        for time in travelTimesMinutes {
            total += time
            cumulative.append(total)
        }
        return cumulative
    }

    // MARK: - Service Calendars

    static let calendars: [GTFSCalendar] = [
        GTFSCalendar(
            serviceId: "WEEKDAY",
            monday: 1, tuesday: 1, wednesday: 1, thursday: 1, friday: 1,
            saturday: 0, sunday: 0,
            startDate: "20240101", endDate: "20261231"
        ),
        GTFSCalendar(
            serviceId: "SATURDAY",
            monday: 0, tuesday: 0, wednesday: 0, thursday: 0, friday: 0,
            saturday: 1, sunday: 0,
            startDate: "20240101", endDate: "20261231"
        ),
        GTFSCalendar(
            serviceId: "SUNDAY",
            monday: 0, tuesday: 0, wednesday: 0, thursday: 0, friday: 0,
            saturday: 0, sunday: 1,
            startDate: "20240101", endDate: "20261231"
        )
    ]

    // MARK: - Schedule Generation

    /// Generates the complete schedule data
    static func generateScheduleData() -> ScheduleData {
        var data = ScheduleData()
        data.stops = stops
        data.calendars = calendars
        data.calendarDates = []

        var allTrips: [GTFSTrip] = []
        var allStopTimes: [GTFSStopTime] = []

        // Generate weekday schedule
        let (weekdayTrips, weekdayStopTimes) = generateDaySchedule(
            serviceId: "WEEKDAY",
            schedule: weekdaySchedule
        )
        allTrips.append(contentsOf: weekdayTrips)
        allStopTimes.append(contentsOf: weekdayStopTimes)

        // Generate Saturday schedule
        let (saturdayTrips, saturdayStopTimes) = generateDaySchedule(
            serviceId: "SATURDAY",
            schedule: weekendSchedule
        )
        allTrips.append(contentsOf: saturdayTrips)
        allStopTimes.append(contentsOf: saturdayStopTimes)

        // Generate Sunday schedule
        let (sundayTrips, sundayStopTimes) = generateDaySchedule(
            serviceId: "SUNDAY",
            schedule: weekendSchedule
        )
        allTrips.append(contentsOf: sundayTrips)
        allStopTimes.append(contentsOf: sundayStopTimes)

        data.trips = allTrips
        data.stopTimes = allStopTimes

        return data
    }

    // MARK: - Weekday Departure Times from Terminals

    /// Weekday departures from Lindenwold (eastbound terminus, trains go westbound to Philly)
    /// Times are in "HH:mm" format, representing departures throughout the day
    static let weekdaySchedule: DaySchedule = DaySchedule(
        // Westbound departures from Lindenwold to 15-16th
        westboundDepartures: [
            // Early morning (5:00 AM - 6:00 AM) - every 20 min
            "05:00", "05:20", "05:40",
            // Morning rush (6:00 AM - 9:00 AM) - every 4-6 min
            "06:00", "06:05", "06:10", "06:15", "06:20", "06:25", "06:30", "06:35", "06:40", "06:45", "06:50", "06:55",
            "07:00", "07:05", "07:10", "07:15", "07:20", "07:25", "07:30", "07:35", "07:40", "07:45", "07:50", "07:55",
            "08:00", "08:05", "08:10", "08:15", "08:20", "08:25", "08:30", "08:35", "08:40", "08:45", "08:50", "08:55",
            // Mid-morning (9:00 AM - 12:00 PM) - every 10-12 min
            "09:00", "09:12", "09:24", "09:36", "09:48",
            "10:00", "10:12", "10:24", "10:36", "10:48",
            "11:00", "11:12", "11:24", "11:36", "11:48",
            // Midday (12:00 PM - 4:00 PM) - every 10-12 min
            "12:00", "12:12", "12:24", "12:36", "12:48",
            "13:00", "13:12", "13:24", "13:36", "13:48",
            "14:00", "14:12", "14:24", "14:36", "14:48",
            "15:00", "15:12", "15:24", "15:36", "15:48",
            // Evening rush (4:00 PM - 7:00 PM) - every 4-6 min
            "16:00", "16:05", "16:10", "16:15", "16:20", "16:25", "16:30", "16:35", "16:40", "16:45", "16:50", "16:55",
            "17:00", "17:05", "17:10", "17:15", "17:20", "17:25", "17:30", "17:35", "17:40", "17:45", "17:50", "17:55",
            "18:00", "18:05", "18:10", "18:15", "18:20", "18:25", "18:30", "18:35", "18:40", "18:45", "18:50", "18:55",
            // Evening (7:00 PM - 10:00 PM) - every 12-15 min
            "19:00", "19:15", "19:30", "19:45",
            "20:00", "20:15", "20:30", "20:45",
            "21:00", "21:15", "21:30", "21:45",
            // Late night (10:00 PM - 1:00 AM) - every 20-30 min
            "22:00", "22:20", "22:40",
            "23:00", "23:20", "23:40",
            "24:00", "24:30"
        ],
        // Eastbound departures from 15-16th to Lindenwold
        eastboundDepartures: [
            // Early morning (5:30 AM - 6:30 AM) - every 20 min
            "05:30", "05:50",
            // Morning rush (6:30 AM - 9:30 AM) - every 4-6 min
            "06:10", "06:15", "06:20", "06:25", "06:30", "06:35", "06:40", "06:45", "06:50", "06:55",
            "07:00", "07:05", "07:10", "07:15", "07:20", "07:25", "07:30", "07:35", "07:40", "07:45", "07:50", "07:55",
            "08:00", "08:05", "08:10", "08:15", "08:20", "08:25", "08:30", "08:35", "08:40", "08:45", "08:50", "08:55",
            "09:00", "09:05", "09:10", "09:15", "09:20", "09:25",
            // Mid-morning (9:30 AM - 12:00 PM) - every 10-12 min
            "09:36", "09:48",
            "10:00", "10:12", "10:24", "10:36", "10:48",
            "11:00", "11:12", "11:24", "11:36", "11:48",
            // Midday (12:00 PM - 4:00 PM) - every 10-12 min
            "12:00", "12:12", "12:24", "12:36", "12:48",
            "13:00", "13:12", "13:24", "13:36", "13:48",
            "14:00", "14:12", "14:24", "14:36", "14:48",
            "15:00", "15:12", "15:24", "15:36", "15:48",
            // Evening rush (4:00 PM - 7:00 PM) - every 4-6 min
            "16:00", "16:05", "16:10", "16:15", "16:20", "16:25", "16:30", "16:35", "16:40", "16:45", "16:50", "16:55",
            "17:00", "17:05", "17:10", "17:15", "17:20", "17:25", "17:30", "17:35", "17:40", "17:45", "17:50", "17:55",
            "18:00", "18:05", "18:10", "18:15", "18:20", "18:25", "18:30", "18:35", "18:40", "18:45", "18:50", "18:55",
            // Evening (7:00 PM - 10:00 PM) - every 12-15 min
            "19:00", "19:15", "19:30", "19:45",
            "20:00", "20:15", "20:30", "20:45",
            "21:00", "21:15", "21:30", "21:45",
            // Late night (10:00 PM - 1:00 AM) - every 20-30 min
            "22:00", "22:20", "22:40",
            "23:00", "23:20", "23:40",
            "24:00", "24:30"
        ]
    )

    /// Weekend departures - less frequent service
    static let weekendSchedule: DaySchedule = DaySchedule(
        westboundDepartures: [
            // Early morning - every 30 min
            "06:00", "06:30",
            "07:00", "07:30",
            // Daytime (8:00 AM - 10:00 PM) - every 15-20 min
            "08:00", "08:20", "08:40",
            "09:00", "09:20", "09:40",
            "10:00", "10:20", "10:40",
            "11:00", "11:20", "11:40",
            "12:00", "12:20", "12:40",
            "13:00", "13:20", "13:40",
            "14:00", "14:20", "14:40",
            "15:00", "15:20", "15:40",
            "16:00", "16:20", "16:40",
            "17:00", "17:20", "17:40",
            "18:00", "18:20", "18:40",
            "19:00", "19:20", "19:40",
            "20:00", "20:20", "20:40",
            "21:00", "21:20", "21:40",
            // Late night - every 30 min
            "22:00", "22:30",
            "23:00", "23:30",
            "24:00"
        ],
        eastboundDepartures: [
            // Early morning - every 30 min
            "06:30",
            "07:00", "07:30",
            // Daytime (8:00 AM - 10:00 PM) - every 15-20 min
            "08:00", "08:20", "08:40",
            "09:00", "09:20", "09:40",
            "10:00", "10:20", "10:40",
            "11:00", "11:20", "11:40",
            "12:00", "12:20", "12:40",
            "13:00", "13:20", "13:40",
            "14:00", "14:20", "14:40",
            "15:00", "15:20", "15:40",
            "16:00", "16:20", "16:40",
            "17:00", "17:20", "17:40",
            "18:00", "18:20", "18:40",
            "19:00", "19:20", "19:40",
            "20:00", "20:20", "20:40",
            "21:00", "21:20", "21:40",
            // Late night - every 30 min
            "22:00", "22:30",
            "23:00", "23:30",
            "24:00", "24:30"
        ]
    )

    struct DaySchedule {
        let westboundDepartures: [String]  // From Lindenwold
        let eastboundDepartures: [String]  // From 15-16th
    }

    // MARK: - Trip Generation

    private static func generateDaySchedule(
        serviceId: String,
        schedule: DaySchedule
    ) -> ([GTFSTrip], [GTFSStopTime]) {
        var trips: [GTFSTrip] = []
        var stopTimes: [GTFSStopTime] = []

        // Generate westbound trips (Lindenwold -> 15-16th)
        for (index, departureTime) in schedule.westboundDepartures.enumerated() {
            let tripId = "\(serviceId)_WB_\(index)"
            let trip = GTFSTrip(
                id: tripId,
                routeId: "PATCO",
                serviceId: serviceId,
                headsign: "15th-16th & Locust",
                directionId: 0
            )
            trips.append(trip)

            // Generate stop times for this trip
            let tripStopTimes = generateStopTimes(
                tripId: tripId,
                startTime: departureTime,
                direction: .westbound
            )
            stopTimes.append(contentsOf: tripStopTimes)
        }

        // Generate eastbound trips (15-16th -> Lindenwold)
        for (index, departureTime) in schedule.eastboundDepartures.enumerated() {
            let tripId = "\(serviceId)_EB_\(index)"
            let trip = GTFSTrip(
                id: tripId,
                routeId: "PATCO",
                serviceId: serviceId,
                headsign: "Lindenwold",
                directionId: 1
            )
            trips.append(trip)

            // Generate stop times for this trip
            let tripStopTimes = generateStopTimes(
                tripId: tripId,
                startTime: departureTime,
                direction: .eastbound
            )
            stopTimes.append(contentsOf: tripStopTimes)
        }

        return (trips, stopTimes)
    }

    private static func generateStopTimes(
        tripId: String,
        startTime: String,
        direction: TrainDirection
    ) -> [GTFSStopTime] {
        var stopTimes: [GTFSStopTime] = []
        let stationOrder: [GTFSStop]
        let travelTimes: [Int]

        switch direction {
        case .westbound:
            // Lindenwold to 15-16th
            stationOrder = stops
            travelTimes = cumulativeTravelTimes
        case .eastbound:
            // 15-16th to Lindenwold (reverse order)
            stationOrder = stops.reversed()
            travelTimes = cumulativeTravelTimes.reversed().map { cumulativeTravelTimes.last! - $0 }
        }

        guard let startMinutes = parseTimeToMinutes(startTime) else {
            return []
        }

        for (sequence, stop) in stationOrder.enumerated() {
            let arrivalMinutes = startMinutes + travelTimes[sequence]
            let timeString = minutesToTimeString(arrivalMinutes)

            let stopTime = GTFSStopTime(
                tripId: tripId,
                arrivalTime: timeString,
                departureTime: timeString,
                stopId: stop.id,
                stopSequence: sequence
            )
            stopTimes.append(stopTime)
        }

        return stopTimes
    }

    private static func parseTimeToMinutes(_ time: String) -> Int? {
        let components = time.split(separator: ":").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }
        return components[0] * 60 + components[1]
    }

    private static func minutesToTimeString(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d:00", hours, mins)
    }
}
