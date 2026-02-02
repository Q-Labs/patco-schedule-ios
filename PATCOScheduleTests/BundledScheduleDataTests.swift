import XCTest
@testable import PATCOSchedule

final class BundledScheduleDataTests: XCTestCase {

    // MARK: - Station Data Tests

    func testBundledStopsCount() {
        XCTAssertEqual(BundledScheduleData.stops.count, 14)
    }

    func testBundledStopsHaveCoordinates() {
        for stop in BundledScheduleData.stops {
            XCTAssertNotNil(stop.latitude, "Stop \(stop.name) should have latitude")
            XCTAssertNotNil(stop.longitude, "Stop \(stop.name) should have longitude")
        }
    }

    func testBundledStopsOrder() {
        let stops = BundledScheduleData.stops
        XCTAssertEqual(stops[0].id, "LINDENWOLD")
        XCTAssertEqual(stops[9].id, "FRANKLIN")
        XCTAssertEqual(stops[13].id, "15-16TH")
    }

    func testBundledStopsGeographicallyReasonable() {
        // PATCO runs roughly NW to SE, so latitudes should generally increase
        // from Lindenwold (south) to Philly stations (north)
        let lindenwold = BundledScheduleData.stops.first { $0.id == "LINDENWOLD" }!
        let fifteenthSt = BundledScheduleData.stops.first { $0.id == "15-16TH" }!

        XCTAssertLessThan(lindenwold.latitude!, fifteenthSt.latitude!)
    }

    // MARK: - Travel Times Tests

    func testTravelTimesCount() {
        XCTAssertEqual(BundledScheduleData.travelTimesMinutes.count, 14)
    }

    func testTravelTimesArePositive() {
        for (index, time) in BundledScheduleData.travelTimesMinutes.enumerated() {
            XCTAssertGreaterThanOrEqual(time, 0, "Travel time at index \(index) should be non-negative")
        }
    }

    func testCumulativeTravelTimesIncreasing() {
        let cumulative = BundledScheduleData.cumulativeTravelTimes
        for i in 1..<cumulative.count {
            XCTAssertGreaterThanOrEqual(cumulative[i], cumulative[i-1],
                "Cumulative times should be non-decreasing")
        }
    }

    func testTotalTravelTimeReasonable() {
        // Total travel time Lindenwold to 15-16th should be around 25-30 minutes
        let totalTime = BundledScheduleData.cumulativeTravelTimes.last!
        XCTAssertGreaterThanOrEqual(totalTime, 20)
        XCTAssertLessThanOrEqual(totalTime, 35)
    }

    // MARK: - Calendar Tests

    func testCalendarsCount() {
        XCTAssertEqual(BundledScheduleData.calendars.count, 3)
    }

    func testCalendarServiceIds() {
        let serviceIds = Set(BundledScheduleData.calendars.map { $0.serviceId })
        XCTAssertTrue(serviceIds.contains("WEEKDAY"))
        XCTAssertTrue(serviceIds.contains("SATURDAY"))
        XCTAssertTrue(serviceIds.contains("SUNDAY"))
    }

    func testWeekdayCalendarConfiguration() {
        let weekday = BundledScheduleData.calendars.first { $0.serviceId == "WEEKDAY" }!
        XCTAssertEqual(weekday.monday, 1)
        XCTAssertEqual(weekday.tuesday, 1)
        XCTAssertEqual(weekday.wednesday, 1)
        XCTAssertEqual(weekday.thursday, 1)
        XCTAssertEqual(weekday.friday, 1)
        XCTAssertEqual(weekday.saturday, 0)
        XCTAssertEqual(weekday.sunday, 0)
    }

    func testSaturdayCalendarConfiguration() {
        let saturday = BundledScheduleData.calendars.first { $0.serviceId == "SATURDAY" }!
        XCTAssertEqual(saturday.monday, 0)
        XCTAssertEqual(saturday.saturday, 1)
        XCTAssertEqual(saturday.sunday, 0)
    }

    func testSundayCalendarConfiguration() {
        let sunday = BundledScheduleData.calendars.first { $0.serviceId == "SUNDAY" }!
        XCTAssertEqual(sunday.monday, 0)
        XCTAssertEqual(sunday.saturday, 0)
        XCTAssertEqual(sunday.sunday, 1)
    }

    // MARK: - Schedule Generation Tests

    func testGenerateScheduleDataReturnsValidData() {
        let data = BundledScheduleData.generateScheduleData()

        XCTAssertTrue(data.isLoaded)
        XCTAssertFalse(data.stops.isEmpty)
        XCTAssertFalse(data.trips.isEmpty)
        XCTAssertFalse(data.stopTimes.isEmpty)
        XCTAssertFalse(data.calendars.isEmpty)
    }

    func testGenerateScheduleDataStopsMatch() {
        let data = BundledScheduleData.generateScheduleData()
        XCTAssertEqual(data.stops.count, BundledScheduleData.stops.count)
    }

    func testGenerateScheduleDataHasWeekdayTrips() {
        let data = BundledScheduleData.generateScheduleData()
        let weekdayTrips = data.trips.filter { $0.serviceId == "WEEKDAY" }
        XCTAssertFalse(weekdayTrips.isEmpty)
    }

    func testGenerateScheduleDataHasWeekendTrips() {
        let data = BundledScheduleData.generateScheduleData()
        let saturdayTrips = data.trips.filter { $0.serviceId == "SATURDAY" }
        let sundayTrips = data.trips.filter { $0.serviceId == "SUNDAY" }
        XCTAssertFalse(saturdayTrips.isEmpty)
        XCTAssertFalse(sundayTrips.isEmpty)
    }

    func testGenerateScheduleDataHasBothDirections() {
        let data = BundledScheduleData.generateScheduleData()

        let westboundTrips = data.trips.filter { $0.directionId == 0 }
        let eastboundTrips = data.trips.filter { $0.directionId == 1 }

        XCTAssertFalse(westboundTrips.isEmpty, "Should have westbound trips")
        XCTAssertFalse(eastboundTrips.isEmpty, "Should have eastbound trips")
    }

    func testGenerateScheduleDataTripsHaveHeadsigns() {
        let data = BundledScheduleData.generateScheduleData()

        for trip in data.trips {
            XCTAssertNotNil(trip.headsign, "Trip \(trip.id) should have a headsign")
            XCTAssertFalse(trip.headsign!.isEmpty, "Trip \(trip.id) headsign should not be empty")
        }
    }

    func testGenerateScheduleDataStopTimesHaveValidTimes() {
        let data = BundledScheduleData.generateScheduleData()

        for stopTime in data.stopTimes {
            // Time format should be HH:mm:ss
            XCTAssertTrue(stopTime.arrivalTime.contains(":"),
                "Arrival time \(stopTime.arrivalTime) should contain ':'")
            XCTAssertTrue(stopTime.departureTime.contains(":"),
                "Departure time \(stopTime.departureTime) should contain ':'")
        }
    }

    func testGenerateScheduleDataStopTimesPerTrip() {
        let data = BundledScheduleData.generateScheduleData()

        // Group stop times by trip
        var stopTimesPerTrip: [String: [GTFSStopTime]] = [:]
        for stopTime in data.stopTimes {
            stopTimesPerTrip[stopTime.tripId, default: []].append(stopTime)
        }

        // Each trip should have 14 stop times (one per station)
        for (tripId, stopTimes) in stopTimesPerTrip {
            XCTAssertEqual(stopTimes.count, 14,
                "Trip \(tripId) should have 14 stop times, got \(stopTimes.count)")
        }
    }

    func testGenerateScheduleDataStopSequenceOrdering() {
        let data = BundledScheduleData.generateScheduleData()

        // Group stop times by trip
        var stopTimesPerTrip: [String: [GTFSStopTime]] = [:]
        for stopTime in data.stopTimes {
            stopTimesPerTrip[stopTime.tripId, default: []].append(stopTime)
        }

        // Stop sequences should be 0-13 for each trip
        for (tripId, stopTimes) in stopTimesPerTrip {
            let sequences = stopTimes.map { $0.stopSequence }.sorted()
            let expected = Array(0..<14)
            XCTAssertEqual(sequences, expected,
                "Trip \(tripId) should have sequences 0-13")
        }
    }

    // MARK: - Weekday Schedule Tests

    func testWeekdayScheduleHasRushHourFrequency() {
        let westboundDepartures = BundledScheduleData.weekdaySchedule.westboundDepartures

        // Count departures between 7:00 and 8:00 (rush hour)
        let rushHourDepartures = westboundDepartures.filter { time in
            time >= "07:00" && time < "08:00"
        }

        // Should have at least 10 departures per hour during rush hour
        XCTAssertGreaterThanOrEqual(rushHourDepartures.count, 10,
            "Rush hour should have frequent service")
    }

    func testWeekdayScheduleCoversFullDay() {
        let westboundDepartures = BundledScheduleData.weekdaySchedule.westboundDepartures

        // Should have early morning service
        let earlyMorning = westboundDepartures.first { $0 < "06:00" }
        XCTAssertNotNil(earlyMorning, "Should have early morning service")

        // Should have late night service
        let lateNight = westboundDepartures.first { $0 >= "23:00" }
        XCTAssertNotNil(lateNight, "Should have late night service")
    }

    // MARK: - Weekend Schedule Tests

    func testWeekendScheduleHasLessFrequentService() {
        let weekdayDepartures = BundledScheduleData.weekdaySchedule.westboundDepartures
        let weekendDepartures = BundledScheduleData.weekendSchedule.westboundDepartures

        XCTAssertLessThan(weekendDepartures.count, weekdayDepartures.count,
            "Weekend should have fewer departures than weekday")
    }

    func testWeekendScheduleHasRegularIntervals() {
        let departures = BundledScheduleData.weekendSchedule.westboundDepartures

        // Filter daytime departures (8:00 - 20:00)
        let daytimeDepartures = departures.filter { time in
            time >= "08:00" && time < "20:00"
        }

        XCTAssertFalse(daytimeDepartures.isEmpty, "Should have daytime weekend service")
    }

    // MARK: - Data Consistency Tests

    func testAllStopIdsInStopTimesExistInStops() {
        let data = BundledScheduleData.generateScheduleData()
        let stopIds = Set(data.stops.map { $0.id })

        for stopTime in data.stopTimes {
            XCTAssertTrue(stopIds.contains(stopTime.stopId),
                "Stop ID \(stopTime.stopId) in stop_times should exist in stops")
        }
    }

    func testAllTripIdsInStopTimesExistInTrips() {
        let data = BundledScheduleData.generateScheduleData()
        let tripIds = Set(data.trips.map { $0.id })

        for stopTime in data.stopTimes {
            XCTAssertTrue(tripIds.contains(stopTime.tripId),
                "Trip ID \(stopTime.tripId) in stop_times should exist in trips")
        }
    }

    func testAllServiceIdsInTripsExistInCalendars() {
        let data = BundledScheduleData.generateScheduleData()
        let serviceIds = Set(data.calendars.map { $0.serviceId })

        for trip in data.trips {
            XCTAssertTrue(serviceIds.contains(trip.serviceId),
                "Service ID \(trip.serviceId) in trips should exist in calendars")
        }
    }
}
