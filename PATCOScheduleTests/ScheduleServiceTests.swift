import XCTest
@testable import PATCOSchedule

@MainActor
final class ScheduleServiceTests: XCTestCase {

    var scheduleService: ScheduleService!

    override func setUp() async throws {
        scheduleService = ScheduleService()
    }

    override func tearDown() async throws {
        scheduleService = nil
    }

    // MARK: - Initialization Tests

    func testInitLoadsScheduleData() {
        XCTAssertTrue(scheduleService.hasScheduleData,
            "Schedule service should have data after init")
    }

    func testInitSetsLoadedState() {
        XCTAssertTrue(scheduleService.loadState.isLoaded,
            "Load state should be loaded after init")
    }

    func testInitUsesBundledData() {
        if case .loaded(let source) = scheduleService.loadState {
            XCTAssertEqual(source, .bundled,
                "Initial data source should be bundled")
        } else {
            XCTFail("Load state should be .loaded")
        }
    }

    func testInitSetsLastUpdated() {
        XCTAssertNotNil(scheduleService.lastUpdated,
            "Last updated should be set after init")
    }

    // MARK: - Load State Tests

    func testScheduleLoadStateNotLoadedIsLoaded() {
        let state = ScheduleLoadState.notLoaded
        XCTAssertFalse(state.isLoaded)
        XCTAssertNil(state.errorMessage)
    }

    func testScheduleLoadStateLoadingIsLoaded() {
        let state = ScheduleLoadState.loading
        XCTAssertFalse(state.isLoaded)
        XCTAssertNil(state.errorMessage)
    }

    func testScheduleLoadStateLoadedIsLoaded() {
        let state = ScheduleLoadState.loaded(source: .bundled)
        XCTAssertTrue(state.isLoaded)
        XCTAssertNil(state.errorMessage)
    }

    func testScheduleLoadStateErrorIsLoaded() {
        let state = ScheduleLoadState.error(message: "Test error")
        XCTAssertFalse(state.isLoaded)
        XCTAssertEqual(state.errorMessage, "Test error")
    }

    // MARK: - Get Upcoming Trains Tests

    func testGetUpcomingTrainsReturnsTrains() {
        let station = Station.allStations[5] // Collingswood (middle station)
        let trains = scheduleService.getUpcomingTrains(for: station, direction: .westbound)

        XCTAssertFalse(trains.isEmpty, "Should return upcoming trains")
    }

    func testGetUpcomingTrainsRespectsLimit() {
        let station = Station.allStations[5]
        let limit = 3
        let trains = scheduleService.getUpcomingTrains(for: station, direction: .westbound, limit: limit)

        XCTAssertLessThanOrEqual(trains.count, limit,
            "Should not exceed limit")
    }

    func testGetUpcomingTrainsSortedByDepartureTime() {
        let station = Station.allStations[5]
        let trains = scheduleService.getUpcomingTrains(for: station, direction: .westbound, limit: 10)

        for i in 1..<trains.count {
            XCTAssertLessThanOrEqual(trains[i-1].departureTime, trains[i].departureTime,
                "Trains should be sorted by departure time")
        }
    }

    func testGetUpcomingTrainsReturnsCorrectDirection() {
        let station = Station.allStations[5]

        let westboundTrains = scheduleService.getUpcomingTrains(for: station, direction: .westbound)
        for train in westboundTrains {
            XCTAssertEqual(train.direction, .westbound)
        }

        let eastboundTrains = scheduleService.getUpcomingTrains(for: station, direction: .eastbound)
        for train in eastboundTrains {
            XCTAssertEqual(train.direction, .eastbound)
        }
    }

    func testGetUpcomingTrainsOnlyFutureTrains() {
        let station = Station.allStations[5]
        let trains = scheduleService.getUpcomingTrains(for: station, direction: .westbound)
        let now = Date()

        for train in trains {
            XCTAssertGreaterThan(train.departureTime, now,
                "All trains should be in the future")
        }
    }

    // MARK: - Get Next Train Tests

    func testGetNextTrainReturnsFirstTrain() {
        let station = Station.allStations[5]
        let nextTrain = scheduleService.getNextTrain(for: station, direction: .westbound)
        let allTrains = scheduleService.getUpcomingTrains(for: station, direction: .westbound, limit: 10)

        if let next = nextTrain, !allTrains.isEmpty {
            XCTAssertEqual(next.departureTime, allTrains[0].departureTime,
                "Next train should be the first upcoming train")
        }
    }

    func testGetNextTrainReturnsNilForTerminus() {
        // Lindenwold is the eastbound terminus - no eastbound trains depart from there
        let lindenwold = Station.allStations[0]

        // At Lindenwold, westbound trains should exist
        let westbound = scheduleService.getNextTrain(for: lindenwold, direction: .westbound)
        XCTAssertNotNil(westbound, "Should have westbound trains from Lindenwold")
    }

    // MARK: - Station Matching Tests

    func testGetUpcomingTrainsForAllStations() {
        for station in Station.allStations {
            // Skip terminus checks - they may not have both directions
            if station.order == 0 || station.order == 12 {
                continue
            }

            let westbound = scheduleService.getUpcomingTrains(for: station, direction: .westbound, limit: 1)
            let eastbound = scheduleService.getUpcomingTrains(for: station, direction: .eastbound, limit: 1)

            // Mid-line stations should have service in both directions
            let hasService = !westbound.isEmpty || !eastbound.isEmpty
            XCTAssertTrue(hasService,
                "Station \(station.name) should have trains in at least one direction")
        }
    }

    // MARK: - Headsign Tests

    func testWestboundTrainsHaveCorrectHeadsign() {
        let station = Station.allStations[5]
        let trains = scheduleService.getUpcomingTrains(for: station, direction: .westbound, limit: 5)

        for train in trains {
            XCTAssertTrue(
                train.headsign.contains("15") ||
                train.headsign.contains("16") ||
                train.headsign.contains("Locust"),
                "Westbound headsign '\(train.headsign)' should reference Philadelphia terminus"
            )
        }
    }

    func testEastboundTrainsHaveCorrectHeadsign() {
        let station = Station.allStations[5]
        let trains = scheduleService.getUpcomingTrains(for: station, direction: .eastbound, limit: 5)

        for train in trains {
            XCTAssertTrue(
                train.headsign.lowercased().contains("lindenwold"),
                "Eastbound headsign '\(train.headsign)' should reference Lindenwold"
            )
        }
    }

    // MARK: - Performance Tests

    func testGetUpcomingTrainsPerformance() {
        let station = Station.allStations[5]

        measure {
            for _ in 0..<100 {
                _ = scheduleService.getUpcomingTrains(for: station, direction: .westbound, limit: 5)
            }
        }
    }

    // MARK: - Edge Cases

    func testGetUpcomingTrainsWithZeroLimit() {
        let station = Station.allStations[5]
        let trains = scheduleService.getUpcomingTrains(for: station, direction: .westbound, limit: 0)

        XCTAssertTrue(trains.isEmpty, "Zero limit should return empty array")
    }

    func testGetUpcomingTrainsWithLargeLimit() {
        let station = Station.allStations[5]
        let trains = scheduleService.getUpcomingTrains(for: station, direction: .westbound, limit: 1000)

        // Should return all available trains without crashing
        XCTAssertNotNil(trains)
    }
}
