import XCTest
@testable import PATCOSchedule

@available(iOS 16.1, *)
final class LiveActivityTests: XCTestCase {

    // MARK: - PATCOActivityAttributes Tests

    func testActivityAttributesCreation() {
        let scheduledDeparture = Date().addingTimeInterval(720) // 12 minutes from now

        let attributes = PATCOActivityAttributes(
            stationName: "Haddonfield",
            direction: "Westbound",
            destination: "15th-16th & Locust",
            tripId: "WEEKDAY_WB_42",
            scheduledDeparture: scheduledDeparture
        )

        XCTAssertEqual(attributes.stationName, "Haddonfield")
        XCTAssertEqual(attributes.direction, "Westbound")
        XCTAssertEqual(attributes.destination, "15th-16th & Locust")
        XCTAssertEqual(attributes.tripId, "WEEKDAY_WB_42")
        XCTAssertEqual(attributes.scheduledDeparture, scheduledDeparture)
    }

    func testContentStateCreation() {
        let state = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 12,
            departureTimeString: "10:42 AM",
            isArrivingSoon: false,
            lastUpdated: Date()
        )

        XCTAssertEqual(state.minutesUntilDeparture, 12)
        XCTAssertEqual(state.departureTimeString, "10:42 AM")
        XCTAssertFalse(state.isArrivingSoon)
    }

    func testContentStateArrivingSoon() {
        let stateNotSoon = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 10,
            departureTimeString: "10:40 AM",
            isArrivingSoon: false,
            lastUpdated: Date()
        )
        XCTAssertFalse(stateNotSoon.isArrivingSoon)

        let stateSoon = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 3,
            departureTimeString: "10:33 AM",
            isArrivingSoon: true,
            lastUpdated: Date()
        )
        XCTAssertTrue(stateSoon.isArrivingSoon)
    }

    func testContentStateFromUpcomingTrain() {
        let departureTime = Date().addingTimeInterval(720) // 12 minutes from now
        let train = UpcomingTrain(
            departureTime: departureTime,
            arrivalTimeString: "10:42:00",
            headsign: "15th-16th & Locust",
            direction: .westbound,
            tripId: "WEEKDAY_WB_42"
        )

        let state = PATCOActivityAttributes.ContentState.from(train: train)

        // Minutes should be approximately 12 (allowing for small time differences)
        XCTAssertGreaterThanOrEqual(state.minutesUntilDeparture, 11)
        XCTAssertLessThanOrEqual(state.minutesUntilDeparture, 13)
        XCTAssertFalse(state.isArrivingSoon)
        XCTAssertFalse(state.departureTimeString.isEmpty)
    }

    func testContentStateFromUpcomingTrainArrivingSoon() {
        let departureTime = Date().addingTimeInterval(180) // 3 minutes from now
        let train = UpcomingTrain(
            departureTime: departureTime,
            arrivalTimeString: "10:33:00",
            headsign: "Lindenwold",
            direction: .eastbound,
            tripId: "WEEKDAY_EB_15"
        )

        let state = PATCOActivityAttributes.ContentState.from(train: train)

        XCTAssertLessThanOrEqual(state.minutesUntilDeparture, 5)
        XCTAssertTrue(state.isArrivingSoon)
    }

    // MARK: - ContentState Codable Tests

    func testContentStateEncodingDecoding() throws {
        let originalState = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 8,
            departureTimeString: "10:38 AM",
            isArrivingSoon: false,
            lastUpdated: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)

        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(PATCOActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decodedState.minutesUntilDeparture, originalState.minutesUntilDeparture)
        XCTAssertEqual(decodedState.departureTimeString, originalState.departureTimeString)
        XCTAssertEqual(decodedState.isArrivingSoon, originalState.isArrivingSoon)
    }

    // MARK: - ContentState Hashable Tests

    func testContentStateHashable() {
        let state1 = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 12,
            departureTimeString: "10:42 AM",
            isArrivingSoon: false,
            lastUpdated: Date()
        )

        let state2 = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 12,
            departureTimeString: "10:42 AM",
            isArrivingSoon: false,
            lastUpdated: state1.lastUpdated
        )

        XCTAssertEqual(state1, state2)
        XCTAssertEqual(state1.hashValue, state2.hashValue)
    }

    func testContentStateDifferentValues() {
        let state1 = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 12,
            departureTimeString: "10:42 AM",
            isArrivingSoon: false,
            lastUpdated: Date()
        )

        let state2 = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 5,
            departureTimeString: "10:35 AM",
            isArrivingSoon: true,
            lastUpdated: Date()
        )

        XCTAssertNotEqual(state1, state2)
    }

    // MARK: - Direction Tests for Live Activity

    func testWestboundDirection() {
        let attributes = PATCOActivityAttributes(
            stationName: "Haddonfield",
            direction: "Westbound",
            destination: "15th-16th & Locust",
            tripId: "WEEKDAY_WB_42",
            scheduledDeparture: Date()
        )

        XCTAssertEqual(attributes.direction, "Westbound")
        XCTAssertEqual(attributes.destination, "15th-16th & Locust")
    }

    func testEastboundDirection() {
        let attributes = PATCOActivityAttributes(
            stationName: "City Hall",
            direction: "Eastbound",
            destination: "Lindenwold",
            tripId: "WEEKDAY_EB_30",
            scheduledDeparture: Date()
        )

        XCTAssertEqual(attributes.direction, "Eastbound")
        XCTAssertEqual(attributes.destination, "Lindenwold")
    }

    // MARK: - Station Name Tests

    func testAllStationNamesValid() {
        for station in Station.allStations {
            let attributes = PATCOActivityAttributes(
                stationName: station.displayName,
                direction: "Westbound",
                destination: "15th-16th & Locust",
                tripId: "TEST",
                scheduledDeparture: Date()
            )

            XCTAssertFalse(attributes.stationName.isEmpty)
            XCTAssertEqual(attributes.stationName, station.displayName)
        }
    }
}

// MARK: - LiveActivityManager Tests

@available(iOS 16.1, *)
final class LiveActivityManagerTests: XCTestCase {

    @MainActor
    func testManagerInitialization() {
        let manager = LiveActivityManager()

        // isSupported depends on device, but should be a boolean
        XCTAssertNotNil(manager.isSupported)

        // No activity should be running initially
        XCTAssertFalse(manager.isActivityRunning)
        XCTAssertNil(manager.currentActivity)
    }

    @MainActor
    func testIsActivityRunningProperty() {
        let manager = LiveActivityManager()

        // Initially no activity
        XCTAssertFalse(manager.isActivityRunning)
    }

    @MainActor
    func testSetScheduleService() {
        let manager = LiveActivityManager()
        let scheduleService = ScheduleService()

        // Should not crash
        manager.setScheduleService(scheduleService)
    }
}
