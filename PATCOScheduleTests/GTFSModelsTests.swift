import XCTest
@testable import PATCOSchedule

final class GTFSModelsTests: XCTestCase {

    let provider = PATCOProvider()

    // MARK: - GTFSStop Tests

    func testGTFSStopDecoding() throws {
        let json = """
        {
            "stop_id": "LINDENWOLD",
            "stop_name": "Lindenwold",
            "stop_lat": 39.8249,
            "stop_lon": -74.9830
        }
        """.data(using: .utf8)!

        let stop = try JSONDecoder().decode(GTFSStop.self, from: json)

        XCTAssertEqual(stop.id, "LINDENWOLD")
        XCTAssertEqual(stop.name, "Lindenwold")
        XCTAssertEqual(stop.latitude, 39.8249)
        XCTAssertEqual(stop.longitude, -74.9830)
    }

    func testGTFSStopDecodingWithoutCoordinates() throws {
        let json = """
        {
            "stop_id": "TEST",
            "stop_name": "Test Station"
        }
        """.data(using: .utf8)!

        let stop = try JSONDecoder().decode(GTFSStop.self, from: json)

        XCTAssertEqual(stop.id, "TEST")
        XCTAssertEqual(stop.name, "Test Station")
        XCTAssertNil(stop.latitude)
        XCTAssertNil(stop.longitude)
    }

    func testGTFSStopHashable() {
        let stop1 = GTFSStop(id: "A", name: "Station A", latitude: nil, longitude: nil)
        let stop2 = GTFSStop(id: "A", name: "Station A", latitude: nil, longitude: nil)
        let stop3 = GTFSStop(id: "B", name: "Station B", latitude: nil, longitude: nil)

        XCTAssertEqual(stop1, stop2)
        XCTAssertNotEqual(stop1, stop3)

        var set: Set<GTFSStop> = []
        set.insert(stop1)
        set.insert(stop2)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - GTFSTrip Tests

    func testGTFSTripDecoding() throws {
        let json = """
        {
            "trip_id": "WEEKDAY_WB_1",
            "route_id": "PATCO",
            "service_id": "WEEKDAY",
            "trip_headsign": "15th-16th & Locust",
            "direction_id": 0
        }
        """.data(using: .utf8)!

        let trip = try JSONDecoder().decode(GTFSTrip.self, from: json)

        XCTAssertEqual(trip.id, "WEEKDAY_WB_1")
        XCTAssertEqual(trip.routeId, "PATCO")
        XCTAssertEqual(trip.serviceId, "WEEKDAY")
        XCTAssertEqual(trip.headsign, "15th-16th & Locust")
        XCTAssertEqual(trip.directionId, 0)
    }

    func testGTFSTripDecodingWithoutOptionals() throws {
        let json = """
        {
            "trip_id": "TRIP1",
            "route_id": "ROUTE1",
            "service_id": "SERVICE1"
        }
        """.data(using: .utf8)!

        let trip = try JSONDecoder().decode(GTFSTrip.self, from: json)

        XCTAssertEqual(trip.id, "TRIP1")
        XCTAssertNil(trip.headsign)
        XCTAssertNil(trip.directionId)
    }

    // MARK: - GTFSStopTime Tests

    func testGTFSStopTimeDecoding() throws {
        let json = """
        {
            "trip_id": "TRIP1",
            "arrival_time": "07:30:00",
            "departure_time": "07:31:00",
            "stop_id": "HADDONFIELD",
            "stop_sequence": 3
        }
        """.data(using: .utf8)!

        let stopTime = try JSONDecoder().decode(GTFSStopTime.self, from: json)

        XCTAssertEqual(stopTime.tripId, "TRIP1")
        XCTAssertEqual(stopTime.arrivalTime, "07:30:00")
        XCTAssertEqual(stopTime.departureTime, "07:31:00")
        XCTAssertEqual(stopTime.stopId, "HADDONFIELD")
        XCTAssertEqual(stopTime.stopSequence, 3)
    }

    // MARK: - GTFSCalendar Tests

    func testGTFSCalendarDecoding() throws {
        let json = """
        {
            "service_id": "WEEKDAY",
            "monday": 1,
            "tuesday": 1,
            "wednesday": 1,
            "thursday": 1,
            "friday": 1,
            "saturday": 0,
            "sunday": 0,
            "start_date": "20240101",
            "end_date": "20261231"
        }
        """.data(using: .utf8)!

        let calendar = try JSONDecoder().decode(GTFSCalendar.self, from: json)

        XCTAssertEqual(calendar.serviceId, "WEEKDAY")
        XCTAssertEqual(calendar.monday, 1)
        XCTAssertEqual(calendar.saturday, 0)
        XCTAssertEqual(calendar.sunday, 0)
    }

    func testGTFSCalendarIsActiveOn() throws {
        let weekdayCalendar = GTFSCalendar(
            serviceId: "WEEKDAY",
            monday: 1, tuesday: 1, wednesday: 1, thursday: 1, friday: 1,
            saturday: 0, sunday: 0,
            startDate: "20240101", endDate: "20261231"
        )

        // Sunday = 1, Monday = 2, ... Saturday = 7 in Calendar.component(.weekday)
        XCTAssertFalse(weekdayCalendar.isActiveOn(weekday: 1)) // Sunday
        XCTAssertTrue(weekdayCalendar.isActiveOn(weekday: 2))  // Monday
        XCTAssertTrue(weekdayCalendar.isActiveOn(weekday: 3))  // Tuesday
        XCTAssertTrue(weekdayCalendar.isActiveOn(weekday: 4))  // Wednesday
        XCTAssertTrue(weekdayCalendar.isActiveOn(weekday: 5))  // Thursday
        XCTAssertTrue(weekdayCalendar.isActiveOn(weekday: 6))  // Friday
        XCTAssertFalse(weekdayCalendar.isActiveOn(weekday: 7)) // Saturday
    }

    func testGTFSCalendarWeekendService() {
        let saturdayCalendar = GTFSCalendar(
            serviceId: "SATURDAY",
            monday: 0, tuesday: 0, wednesday: 0, thursday: 0, friday: 0,
            saturday: 1, sunday: 0,
            startDate: "20240101", endDate: "20261231"
        )

        XCTAssertFalse(saturdayCalendar.isActiveOn(weekday: 2)) // Monday
        XCTAssertTrue(saturdayCalendar.isActiveOn(weekday: 7))  // Saturday
        XCTAssertFalse(saturdayCalendar.isActiveOn(weekday: 1)) // Sunday
    }

    // MARK: - Station Tests (via PATCOProvider)

    func testProviderStationsCount() {
        XCTAssertEqual(provider.stations.count, 14)
    }

    func testProviderStationOrdering() {
        let stations = provider.stations
        XCTAssertEqual(stations[0].name, "Lindenwold")
        XCTAssertEqual(stations[0].order, 0)
        XCTAssertEqual(stations[9].name, "Franklin Square")
        XCTAssertEqual(stations[9].order, 9)
        XCTAssertEqual(stations[13].name, "15-16th and Locust")
        XCTAssertEqual(stations[13].order, 13)
    }

    func testProviderFindStation() {
        // Exact match
        let lindenwold = provider.findStation(matching: "Lindenwold")
        XCTAssertNotNil(lindenwold)
        XCTAssertEqual(lindenwold?.id, "LINDENWOLD")

        // Partial match
        let ferry = provider.findStation(matching: "Ferry")
        XCTAssertNotNil(ferry)
        XCTAssertEqual(ferry?.id, "FERRY")

        // Case insensitive
        let haddonfield = provider.findStation(matching: "HADDONFIELD")
        XCTAssertNotNil(haddonfield)
        XCTAssertEqual(haddonfield?.name, "Haddonfield")

        // ID match
        let cityHall = provider.findStation(matching: "CITYHALL")
        XCTAssertNotNil(cityHall)
        XCTAssertEqual(cityHall?.name, "City Hall")
    }

    func testProviderFindStationNoMatch() {
        let notFound = provider.findStation(matching: "NonExistentStation")
        XCTAssertNil(notFound)
    }

    // MARK: - TransitDirection Tests

    func testProviderDirectionsCount() {
        XCTAssertEqual(provider.directions.count, 2)
    }

    func testProviderDirectionDestinations() {
        let eastbound = provider.directions.first { $0.id == "eastbound" }
        let westbound = provider.directions.first { $0.id == "westbound" }

        XCTAssertNotNil(eastbound)
        XCTAssertNotNil(westbound)
        XCTAssertEqual(eastbound?.destination, "Lindenwold")
        XCTAssertTrue(westbound?.destination.contains("Locust") ?? false)
    }

    func testProviderDirectionIdentifiers() {
        let ids = Set(provider.directions.map { $0.id })
        XCTAssertTrue(ids.contains("eastbound"))
        XCTAssertTrue(ids.contains("westbound"))
    }

    // MARK: - UpcomingTrain Tests

    func testUpcomingTrainMinutesUntilDeparture() {
        let futureDate = Date().addingTimeInterval(300) // 5 minutes from now
        let direction = provider.directions.first { $0.id == "eastbound" }!
        let train = UpcomingTrain(
            departureTime: futureDate,
            arrivalTimeString: "12:00:00",
            headsign: "Lindenwold",
            direction: direction,
            tripId: "TEST"
        )

        // Should be approximately 5 minutes (allowing for test execution time)
        XCTAssertTrue(train.minutesUntilDeparture >= 4)
        XCTAssertTrue(train.minutesUntilDeparture <= 5)
    }

    func testUpcomingTrainMinutesUntilDeparturePastTrain() {
        let pastDate = Date().addingTimeInterval(-300) // 5 minutes ago
        let direction = provider.directions.first { $0.id == "eastbound" }!
        let train = UpcomingTrain(
            departureTime: pastDate,
            arrivalTimeString: "12:00:00",
            headsign: "Lindenwold",
            direction: direction,
            tripId: "TEST"
        )

        XCTAssertEqual(train.minutesUntilDeparture, 0)
    }

    func testUpcomingTrainFormattedDepartureTime() {
        let components = DateComponents(hour: 14, minute: 30)
        let date = Calendar.current.date(from: components)!
        let direction = provider.directions.first { $0.id == "westbound" }!
        let train = UpcomingTrain(
            departureTime: date,
            arrivalTimeString: "14:30:00",
            headsign: "Test",
            direction: direction,
            tripId: "TEST"
        )

        // The formatted time should contain the hour and minute
        let formatted = train.formattedDepartureTime
        XCTAssertTrue(formatted.contains("2:30") || formatted.contains("14:30"))
    }

    // MARK: - ScheduleData Tests

    func testScheduleDataIsLoadedEmpty() {
        let emptyData = ScheduleData()
        XCTAssertFalse(emptyData.isLoaded)
    }

    func testScheduleDataIsLoadedWithData() {
        var data = ScheduleData()
        data.stops = [GTFSStop(id: "A", name: "A", latitude: nil, longitude: nil)]
        data.trips = [GTFSTrip(id: "T1", routeId: "R1", serviceId: "S1", headsign: nil, directionId: nil)]
        data.stopTimes = [GTFSStopTime(tripId: "T1", arrivalTime: "12:00:00", departureTime: "12:00:00", stopId: "A", stopSequence: 0)]

        XCTAssertTrue(data.isLoaded)
    }
}
