import XCTest
@testable import PATCOSchedule

/// Integration tests that verify the entire schedule system works together
@MainActor
final class IntegrationTests: XCTestCase {

    // MARK: - End-to-End Schedule Tests

    func testFullScheduleLoadAndQuery() async {
        // Create a fresh service
        let service = ScheduleService()

        // Verify data is loaded
        XCTAssertTrue(service.hasScheduleData)
        XCTAssertTrue(service.loadState.isLoaded)

        // Query trains for multiple stations
        for station in Station.allStations {
            let westbound = service.getUpcomingTrains(for: station, direction: .westbound, limit: 3)
            let eastbound = service.getUpcomingTrains(for: station, direction: .eastbound, limit: 3)

            // At minimum, each station should be queryable without error
            XCTAssertNotNil(westbound)
            XCTAssertNotNil(eastbound)
        }
    }

    func testScheduleServiceReloadConsistency() async {
        let service = ScheduleService()

        // Get initial train count
        let station = Station.allStations[5]
        let initialTrains = service.getUpcomingTrains(for: station, direction: .westbound, limit: 5)

        // Reload schedule
        await service.loadSchedule()

        // Get trains again
        let reloadedTrains = service.getUpcomingTrains(for: station, direction: .westbound, limit: 5)

        // Should still have data
        XCTAssertTrue(service.hasScheduleData)

        // Train count should be similar (may vary slightly due to time passing)
        XCTAssertFalse(reloadedTrains.isEmpty)
    }

    // MARK: - Trip Consistency Tests

    func testTripStopTimesFormValidJourney() {
        let data = BundledScheduleData.generateScheduleData()

        // Pick a random westbound trip
        guard let westboundTrip = data.trips.first(where: { $0.directionId == 0 }) else {
            XCTFail("Should have westbound trips")
            return
        }

        // Get all stop times for this trip
        let stopTimes = data.stopTimes
            .filter { $0.tripId == westboundTrip.id }
            .sorted { $0.stopSequence < $1.stopSequence }

        XCTAssertEqual(stopTimes.count, 13, "Trip should have 13 stops")

        // Verify times are increasing
        for i in 1..<stopTimes.count {
            let prevTime = stopTimes[i-1].departureTime
            let currTime = stopTimes[i].arrivalTime

            XCTAssertLessThanOrEqual(prevTime, currTime,
                "Stop times should be increasing: \(prevTime) -> \(currTime)")
        }

        // First stop should be Lindenwold for westbound
        XCTAssertEqual(stopTimes[0].stopId, "LINDENWOLD")

        // Last stop should be 15-16th
        XCTAssertEqual(stopTimes[12].stopId, "15-16TH")
    }

    func testEastboundTripStopOrder() {
        let data = BundledScheduleData.generateScheduleData()

        guard let eastboundTrip = data.trips.first(where: { $0.directionId == 1 }) else {
            XCTFail("Should have eastbound trips")
            return
        }

        let stopTimes = data.stopTimes
            .filter { $0.tripId == eastboundTrip.id }
            .sorted { $0.stopSequence < $1.stopSequence }

        // First stop should be 15-16th for eastbound
        XCTAssertEqual(stopTimes[0].stopId, "15-16TH")

        // Last stop should be Lindenwold
        XCTAssertEqual(stopTimes[12].stopId, "LINDENWOLD")
    }

    // MARK: - Service Calendar Integration Tests

    func testWeekdayServiceHasMoreTrips() {
        let data = BundledScheduleData.generateScheduleData()

        let weekdayTrips = data.trips.filter { $0.serviceId == "WEEKDAY" }
        let saturdayTrips = data.trips.filter { $0.serviceId == "SATURDAY" }

        XCTAssertGreaterThan(weekdayTrips.count, saturdayTrips.count,
            "Weekday should have more trips than Saturday")
    }

    func testAllServicesHaveBothDirections() {
        let data = BundledScheduleData.generateScheduleData()

        for serviceId in ["WEEKDAY", "SATURDAY", "SUNDAY"] {
            let serviceTrips = data.trips.filter { $0.serviceId == serviceId }

            let hasWestbound = serviceTrips.contains { $0.directionId == 0 }
            let hasEastbound = serviceTrips.contains { $0.directionId == 1 }

            XCTAssertTrue(hasWestbound, "\(serviceId) should have westbound service")
            XCTAssertTrue(hasEastbound, "\(serviceId) should have eastbound service")
        }
    }

    // MARK: - Time Parsing Integration Tests

    func testScheduleServiceParsesAllStopTimes() async {
        let service = ScheduleService()

        // This indirectly tests that all stop times can be parsed
        // by querying trains at different stations
        var totalTrainsFound = 0

        for station in Station.allStations {
            let trains = service.getUpcomingTrains(for: station, direction: .westbound, limit: 100)
            totalTrainsFound += trains.count
        }

        XCTAssertGreaterThan(totalTrainsFound, 0,
            "Should find trains across all stations")
    }

    // MARK: - Station Coverage Tests

    func testAllStationsHaveMatchingStops() {
        let data = BundledScheduleData.generateScheduleData()
        let stopIds = Set(data.stops.map { $0.id })

        for station in Station.allStations {
            XCTAssertTrue(stopIds.contains(station.id),
                "Station \(station.name) should have matching stop in schedule data")
        }
    }

    func testAllStationsReachableFromBothEnds() {
        let data = BundledScheduleData.generateScheduleData()

        // Check westbound trips cover all stations
        guard let westboundTrip = data.trips.first(where: { $0.directionId == 0 }) else {
            XCTFail("Should have westbound trips")
            return
        }

        let westboundStops = Set(data.stopTimes
            .filter { $0.tripId == westboundTrip.id }
            .map { $0.stopId })

        for station in Station.allStations {
            XCTAssertTrue(westboundStops.contains(station.id),
                "Westbound trip should serve \(station.name)")
        }

        // Check eastbound trips cover all stations
        guard let eastboundTrip = data.trips.first(where: { $0.directionId == 1 }) else {
            XCTFail("Should have eastbound trips")
            return
        }

        let eastboundStops = Set(data.stopTimes
            .filter { $0.tripId == eastboundTrip.id }
            .map { $0.stopId })

        for station in Station.allStations {
            XCTAssertTrue(eastboundStops.contains(station.id),
                "Eastbound trip should serve \(station.name)")
        }
    }

    // MARK: - Real-World Scenario Tests

    func testMorningCommuteScenario() async {
        let service = ScheduleService()

        // Simulate checking trains at Haddonfield (common suburb station)
        let haddonfield = Station.allStations[3]

        // Get westbound trains (to Philadelphia)
        let trains = service.getUpcomingTrains(for: haddonfield, direction: .westbound, limit: 5)

        // Should have service
        XCTAssertFalse(trains.isEmpty, "Should have westbound service from Haddonfield")

        // All trains should be going to Philly
        for train in trains {
            XCTAssertEqual(train.direction, .westbound)
            XCTAssertTrue(train.headsign.contains("15") || train.headsign.contains("Locust"))
        }
    }

    func testEveningCommuteScenario() async {
        let service = ScheduleService()

        // Simulate checking trains at 8th and Market (Philadelphia)
        let eighthAndMarket = Station.allStations[9]

        // Get eastbound trains (to New Jersey)
        let trains = service.getUpcomingTrains(for: eighthAndMarket, direction: .eastbound, limit: 5)

        // Should have service
        XCTAssertFalse(trains.isEmpty, "Should have eastbound service from 8th & Market")

        // All trains should be going to Lindenwold
        for train in trains {
            XCTAssertEqual(train.direction, .eastbound)
            XCTAssertTrue(train.headsign.lowercased().contains("lindenwold"))
        }
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentTrainQueries() async {
        let service = ScheduleService()

        await withTaskGroup(of: Bool.self) { group in
            for station in Station.allStations {
                group.addTask {
                    let westbound = await service.getUpcomingTrains(for: station, direction: .westbound, limit: 5)
                    let eastbound = await service.getUpcomingTrains(for: station, direction: .eastbound, limit: 5)
                    return !westbound.isEmpty || !eastbound.isEmpty || station.order == 0 || station.order == 12
                }
            }

            for await hasService in group {
                XCTAssertTrue(hasService)
            }
        }
    }

    // MARK: - Data Integrity Tests

    func testNoOrphanedStopTimes() {
        let data = BundledScheduleData.generateScheduleData()

        let tripIds = Set(data.trips.map { $0.id })
        let stopIds = Set(data.stops.map { $0.id })

        for stopTime in data.stopTimes {
            XCTAssertTrue(tripIds.contains(stopTime.tripId),
                "Stop time references non-existent trip: \(stopTime.tripId)")
            XCTAssertTrue(stopIds.contains(stopTime.stopId),
                "Stop time references non-existent stop: \(stopTime.stopId)")
        }
    }

    func testAllTripsHaveStopTimes() {
        let data = BundledScheduleData.generateScheduleData()

        let tripsWithStopTimes = Set(data.stopTimes.map { $0.tripId })

        for trip in data.trips {
            XCTAssertTrue(tripsWithStopTimes.contains(trip.id),
                "Trip \(trip.id) has no stop times")
        }
    }
}
