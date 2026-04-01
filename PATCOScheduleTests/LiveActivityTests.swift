import XCTest
@testable import PATCOSchedule

@available(iOS 16.1, *)
final class LiveActivityTests: XCTestCase {

    let provider = PATCOProvider()

    var westbound: TransitDirection { provider.directions.first { $0.id == "westbound" }! }
    var eastbound: TransitDirection { provider.directions.first { $0.id == "eastbound" }! }

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
            secondsUntilDeparture: 0,
            departureTimeString: "10:42 AM",
            isArrivingSoon: false,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: Date()
        )

        XCTAssertEqual(state.minutesUntilDeparture, 12)
        XCTAssertEqual(state.departureTimeString, "10:42 AM")
        XCTAssertFalse(state.isArrivingSoon)
        XCTAssertFalse(state.showSeconds)
        XCTAssertFalse(state.hasDeparted)
    }

    func testContentStateArrivingSoon() {
        let stateNotSoon = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 10,
            secondsUntilDeparture: 0,
            departureTimeString: "10:40 AM",
            isArrivingSoon: false,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: Date()
        )
        XCTAssertFalse(stateNotSoon.isArrivingSoon)

        let stateSoon = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 3,
            secondsUntilDeparture: 0,
            departureTimeString: "10:33 AM",
            isArrivingSoon: true,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: Date()
        )
        XCTAssertTrue(stateSoon.isArrivingSoon)
    }

    func testContentStateShowSeconds() {
        // Under 1 minute - should show seconds
        let stateUnder1Min = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 0,
            secondsUntilDeparture: 45,
            departureTimeString: "10:30 AM",
            isArrivingSoon: true,
            showSeconds: true,
            hasDeparted: false,
            lastUpdated: Date()
        )
        XCTAssertTrue(stateUnder1Min.showSeconds)
        XCTAssertEqual(stateUnder1Min.secondsUntilDeparture, 45)

        // Over 1 minute - should not show seconds
        let stateOver1Min = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 5,
            secondsUntilDeparture: 0,
            departureTimeString: "10:35 AM",
            isArrivingSoon: true,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: Date()
        )
        XCTAssertFalse(stateOver1Min.showSeconds)
    }

    func testContentStateHasDeparted() {
        let departedState = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 0,
            secondsUntilDeparture: 0,
            departureTimeString: "10:30 AM",
            isArrivingSoon: false,
            showSeconds: false,
            hasDeparted: true,
            lastUpdated: Date()
        )
        XCTAssertTrue(departedState.hasDeparted)
    }

    func testContentStateFromUpcomingTrain() {
        let departureTime = Date().addingTimeInterval(720) // 12 minutes from now
        let train = UpcomingTrain(
            departureTime: departureTime,
            arrivalTimeString: "10:42:00",
            headsign: "15th-16th & Locust",
            direction: westbound,
            tripId: "WEEKDAY_WB_42"
        )

        let state = PATCOActivityAttributes.ContentState.from(train: train)

        // Minutes should be approximately 12 (allowing for small time differences)
        XCTAssertGreaterThanOrEqual(state.minutesUntilDeparture, 11)
        XCTAssertLessThanOrEqual(state.minutesUntilDeparture, 13)
        XCTAssertFalse(state.isArrivingSoon)
        XCTAssertFalse(state.showSeconds)
        XCTAssertFalse(state.hasDeparted)
        XCTAssertFalse(state.departureTimeString.isEmpty)
    }

    func testContentStateFromUpcomingTrainArrivingSoon() {
        let departureTime = Date().addingTimeInterval(180) // 3 minutes from now
        let train = UpcomingTrain(
            departureTime: departureTime,
            arrivalTimeString: "10:33:00",
            headsign: "Lindenwold",
            direction: eastbound,
            tripId: "WEEKDAY_EB_15"
        )

        let state = PATCOActivityAttributes.ContentState.from(train: train)

        XCTAssertLessThanOrEqual(state.minutesUntilDeparture, 5)
        XCTAssertTrue(state.isArrivingSoon)
        XCTAssertFalse(state.showSeconds) // Still over 1 minute
    }

    func testContentStateFromUpcomingTrainUnder1Minute() {
        let departureTime = Date().addingTimeInterval(45) // 45 seconds from now
        let train = UpcomingTrain(
            departureTime: departureTime,
            arrivalTimeString: "10:30:00",
            headsign: "Lindenwold",
            direction: eastbound,
            tripId: "WEEKDAY_EB_15"
        )

        let state = PATCOActivityAttributes.ContentState.from(train: train)

        XCTAssertEqual(state.minutesUntilDeparture, 0)
        XCTAssertTrue(state.showSeconds)
        XCTAssertGreaterThan(state.secondsUntilDeparture, 40)
        XCTAssertLessThanOrEqual(state.secondsUntilDeparture, 46)
    }

    // MARK: - ContentState Codable Tests

    func testContentStateEncodingDecoding() throws {
        let originalState = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 8,
            secondsUntilDeparture: 30,
            departureTimeString: "10:38 AM",
            isArrivingSoon: false,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)

        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(PATCOActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decodedState.minutesUntilDeparture, originalState.minutesUntilDeparture)
        XCTAssertEqual(decodedState.secondsUntilDeparture, originalState.secondsUntilDeparture)
        XCTAssertEqual(decodedState.departureTimeString, originalState.departureTimeString)
        XCTAssertEqual(decodedState.isArrivingSoon, originalState.isArrivingSoon)
        XCTAssertEqual(decodedState.showSeconds, originalState.showSeconds)
        XCTAssertEqual(decodedState.hasDeparted, originalState.hasDeparted)
    }

    // MARK: - ContentState Hashable Tests

    func testContentStateHashable() {
        let date = Date()
        let state1 = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 12,
            secondsUntilDeparture: 0,
            departureTimeString: "10:42 AM",
            isArrivingSoon: false,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: date
        )

        let state2 = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 12,
            secondsUntilDeparture: 0,
            departureTimeString: "10:42 AM",
            isArrivingSoon: false,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: date
        )

        XCTAssertEqual(state1, state2)
        XCTAssertEqual(state1.hashValue, state2.hashValue)
    }

    func testContentStateDifferentValues() {
        let state1 = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 12,
            secondsUntilDeparture: 0,
            departureTimeString: "10:42 AM",
            isArrivingSoon: false,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: Date()
        )

        let state2 = PATCOActivityAttributes.ContentState(
            minutesUntilDeparture: 5,
            secondsUntilDeparture: 0,
            departureTimeString: "10:35 AM",
            isArrivingSoon: true,
            showSeconds: false,
            hasDeparted: false,
            lastUpdated: Date()
        )

        XCTAssertNotEqual(state1, state2)
    }

    // MARK: - Direction Tests for Live Activity

    func testWestboundDirection() {
        let attributes = PATCOActivityAttributes(
            stationName: "Haddonfield",
            direction: westbound.displayName,
            destination: westbound.destination,
            tripId: "WEEKDAY_WB_42",
            scheduledDeparture: Date()
        )

        XCTAssertEqual(attributes.direction, "Westbound")
        XCTAssertTrue(attributes.destination.contains("Locust"))
    }

    func testEastboundDirection() {
        let attributes = PATCOActivityAttributes(
            stationName: "City Hall",
            direction: eastbound.displayName,
            destination: eastbound.destination,
            tripId: "WEEKDAY_EB_30",
            scheduledDeparture: Date()
        )

        XCTAssertEqual(attributes.direction, "Eastbound")
        XCTAssertEqual(attributes.destination, "Lindenwold")
    }

    // MARK: - Station Name Tests

    func testAllStationNamesValid() {
        for station in provider.stations {
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
