import XCTest
import SwiftUI
import SnapshotTesting
@testable import PATCOSchedule

private let provider  = PATCOProvider()
private let eastbound = PATCOProvider().directions.first { $0.id == "eastbound" }!
private let westbound = PATCOProvider().directions.first { $0.id == "westbound" }!

/// Builds an UpcomingTrain whose minutesUntilDeparture equals `minutes`.
/// The +30 s buffer keeps the integer stable during test execution since
/// minutesUntilDeparture truncates (not rounds) the interval.
private func train(minutes: Int, headsign: String, direction: TransitDirection) -> UpcomingTrain {
    UpcomingTrain(
        departureTime: Date().addingTimeInterval(Double(minutes) * 60 + 30),
        arrivalTimeString: "10:30:00",
        headsign: headsign,
        direction: direction,
        tripId: "SNAPSHOT_\(minutes)"
    )
}

// MARK: - TrainRowView

final class TrainRowViewSnapshotTests: XCTestCase {
    // Uncomment the next line locally when intentionally updating reference images:
    // override func setUp() { super.setUp(); isRecording = true }

    private func snap(_ train: UpcomingTrain, _ scheme: ColorScheme, name: String,
                      file: StaticString = #file, line: UInt = #line) {
        let view = TrainRowView(train: train)
            .frame(width: 390)
            .padding(.horizontal, 16)
            .preferredColorScheme(scheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 80)),
                       named: name, file: file, line: line)
    }

    func testGreenLight()  { snap(train(minutes: 8, headsign: "Lindenwold",        direction: eastbound), .light, name: "trainRow-green-light") }
    func testGreenDark()   { snap(train(minutes: 8, headsign: "Lindenwold",        direction: eastbound), .dark,  name: "trainRow-green-dark") }
    func testOrangeLight() { snap(train(minutes: 4, headsign: "15th-16th & Locust", direction: westbound), .light, name: "trainRow-orange-light") }
    func testOrangeDark()  { snap(train(minutes: 4, headsign: "15th-16th & Locust", direction: westbound), .dark,  name: "trainRow-orange-dark") }
    func testRedLight()    { snap(train(minutes: 2, headsign: "Lindenwold",        direction: eastbound), .light, name: "trainRow-red-light") }
    func testRedDark()     { snap(train(minutes: 2, headsign: "Lindenwold",        direction: eastbound), .dark,  name: "trainRow-red-dark") }
}

// MARK: - TrainRowCompactView

final class TrainRowCompactViewSnapshotTests: XCTestCase {
    private func snap(_ train: UpcomingTrain, _ scheme: ColorScheme, name: String,
                      file: StaticString = #file, line: UInt = #line) {
        let view = TrainRowCompactView(train: train)
            .frame(width: 320)
            .padding(.horizontal, 16)
            .preferredColorScheme(scheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 320, height: 44)),
                       named: name, file: file, line: line)
    }

    func testGreenLight()  { snap(train(minutes: 10, headsign: "Lindenwold",         direction: eastbound), .light, name: "compactRow-green-light") }
    func testOrangeLight() { snap(train(minutes: 3,  headsign: "15th-16th & Locust", direction: westbound), .light, name: "compactRow-orange-light") }
    func testOrangeDark()  { snap(train(minutes: 3,  headsign: "15th-16th & Locust", direction: westbound), .dark,  name: "compactRow-orange-dark") }
}

// MARK: - StationRowView

final class StationRowViewSnapshotTests: XCTestCase {
    private let simple   = Station(id: "HADDONFIELD", name: "Haddonfield",  displayName: "Haddonfield", order: 3)
    private let subtitle = Station(id: "FERRY",       name: "Ferry Avenue", displayName: "Ferry Ave",   order: 6)

    private func snap(station: Station, isSelected: Bool, _ scheme: ColorScheme, name: String,
                      file: StaticString = #file, line: UInt = #line) {
        let view = StationRowView(station: station, isSelected: isSelected)
            .frame(width: 390)
            .padding(.horizontal, 16)
            .preferredColorScheme(scheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 60)),
                       named: name, file: file, line: line)
    }

    func testUnselectedLight()    { snap(station: simple,   isSelected: false, .light, name: "stationRow-unselected-light") }
    func testSelectedLight()      { snap(station: simple,   isSelected: true,  .light, name: "stationRow-selected-light") }
    func testSelectedDark()       { snap(station: simple,   isSelected: true,  .dark,  name: "stationRow-selected-dark") }
    func testUnselectedDark()     { snap(station: simple,   isSelected: false, .dark,  name: "stationRow-unselected-dark") }
    func testSubtitleUnselected() { snap(station: subtitle, isSelected: false, .light, name: "stationRow-subtitle-unselected") }
    func testSubtitleSelected()   { snap(station: subtitle, isSelected: true,  .light, name: "stationRow-subtitle-selected") }
}

// MARK: - StationListView

final class StationListViewSnapshotTests: XCTestCase {
    @MainActor func testNoSelectionLight() {
        let view = NavigationStack {
            StationListView(selectedStation: .constant(nil))
                .environmentObject(ScheduleService())
        }.preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)),
                       named: "stationList-noSelection-light")
    }

    @MainActor func testWithSelectionLight() {
        let view = NavigationStack {
            StationListView(selectedStation: .constant(provider.stations[3]))
                .environmentObject(ScheduleService())
        }.preferredColorScheme(.light)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)),
                       named: "stationList-withSelection-light")
    }

    @MainActor func testNoSelectionDark() {
        let view = NavigationStack {
            StationListView(selectedStation: .constant(nil))
                .environmentObject(ScheduleService())
        }.preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)),
                       named: "stationList-noSelection-dark")
    }
}
