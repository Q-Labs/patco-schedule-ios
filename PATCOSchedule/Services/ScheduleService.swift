import Foundation
import Combine

enum ScheduleLoadState: Equatable {
    case notLoaded
    case loading
    case loaded(source: DataSource)
    case error(message: String)

    enum DataSource: String {
        case bundled = "Bundled Schedule"
        case live = "Live GTFS Data"
    }

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

@MainActor
class ScheduleService: ObservableObject {
    @Published var scheduleData: ScheduleData = ScheduleData()
    @Published var loadState: ScheduleLoadState = .notLoaded
    @Published var lastUpdated: Date?

    var isLoading: Bool {
        loadState == .loading
    }

    var hasScheduleData: Bool {
        scheduleData.isLoaded
    }

    private let parser = GTFSParser()
    private var stopIdMapping: [String: String] = [:]

    init() {
        // Immediately load bundled data on init
        loadBundledSchedule()
    }

    // MARK: - Public Methods

    /// Loads schedule data - uses bundled data immediately, then optionally fetches live updates
    func loadSchedule() async {
        // If we don't have data yet, load bundled first
        if !scheduleData.isLoaded {
            loadBundledSchedule()
        }

        // Then try to fetch live GTFS data in background
        await fetchLiveGTFSData()
    }

    /// Forces a refresh from live GTFS source
    func refreshFromLive() async {
        await fetchLiveGTFSData()
    }

    func getUpcomingTrains(for station: Station, direction: TrainDirection, limit: Int = 5) -> [UpcomingTrain] {
        guard scheduleData.isLoaded else { return [] }

        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let todayString = dateFormatter.string(from: now)

        // Get active service IDs for today
        let activeServiceIds = getActiveServiceIds(for: todayString, weekday: currentWeekday)

        // Get stop IDs that match this station
        let matchingStopIds = getStopIds(for: station)

        // Filter trips by direction
        let directionTrips = scheduleData.trips.filter { trip in
            activeServiceIds.contains(trip.serviceId) &&
            matchesDirection(trip: trip, direction: direction)
        }

        let tripIds = Set(directionTrips.map { $0.id })

        // Get stop times for this station on matching trips
        let relevantStopTimes = scheduleData.stopTimes.filter { stopTime in
            tripIds.contains(stopTime.tripId) &&
            matchingStopIds.contains(stopTime.stopId)
        }

        // Convert to UpcomingTrain objects
        var upcomingTrains: [UpcomingTrain] = []

        for stopTime in relevantStopTimes {
            guard let departureDate = parseGTFSTime(stopTime.departureTime, relativeTo: now) else {
                continue
            }

            // Only include trains that haven't departed yet
            if departureDate > now {
                let trip = directionTrips.first { $0.id == stopTime.tripId }
                let headsign = trip?.headsign ?? direction.destination

                let train = UpcomingTrain(
                    departureTime: departureDate,
                    arrivalTimeString: stopTime.arrivalTime,
                    headsign: headsign,
                    direction: direction,
                    tripId: stopTime.tripId
                )
                upcomingTrains.append(train)
            }
        }

        // Sort by departure time and limit
        upcomingTrains.sort { $0.departureTime < $1.departureTime }
        return Array(upcomingTrains.prefix(limit))
    }

    func getNextTrain(for station: Station, direction: TrainDirection) -> UpcomingTrain? {
        return getUpcomingTrains(for: station, direction: direction, limit: 1).first
    }

    // MARK: - Private Methods

    private func loadBundledSchedule() {
        loadState = .loading

        // Generate schedule from bundled data
        scheduleData = BundledScheduleData.generateScheduleData()
        buildStopIdMapping()

        if scheduleData.isLoaded {
            loadState = .loaded(source: .bundled)
            lastUpdated = Date()
        } else {
            loadState = .error(message: "Failed to load schedule data. Please restart the app.")
        }
    }

    private func fetchLiveGTFSData() async {
        // Don't show loading state if we already have bundled data
        let hadData = scheduleData.isLoaded

        if !hadData {
            loadState = .loading
        }

        do {
            let liveData = try await parser.downloadAndParseGTFS()

            // Only use live data if it's valid
            if liveData.isLoaded {
                scheduleData = liveData
                buildStopIdMapping()
                loadState = .loaded(source: .live)
                lastUpdated = Date()
            }
        } catch {
            // If we already have bundled data, just log the error silently
            // Otherwise show error state
            if !hadData {
                loadState = .error(message: "Unable to load schedule data. Please check your internet connection and try again.")
            }
            // If we have bundled data, keep using it - don't change the state
            print("Failed to fetch live GTFS data: \(error.localizedDescription)")
        }
    }

    private func buildStopIdMapping() {
        stopIdMapping.removeAll()

        for stop in scheduleData.stops {
            if let station = Station.findStation(matching: stop.name) {
                stopIdMapping[stop.id] = station.id
            }
        }
    }

    private func getStopIds(for station: Station) -> Set<String> {
        var ids: Set<String> = []

        for stop in scheduleData.stops {
            let normalizedStopName = stop.name.lowercased()
            let stationName = station.name.lowercased()
            let stationDisplayName = station.displayName.lowercased()

            if normalizedStopName.contains(stationName) ||
               stationName.contains(normalizedStopName) ||
               normalizedStopName.contains(stationDisplayName) ||
               stop.id.lowercased().contains(station.id.lowercased()) ||
               station.id.lowercased() == stop.id.lowercased() {
                ids.insert(stop.id)
            }
        }

        // If no matches found, try fuzzy matching
        if ids.isEmpty {
            for stop in scheduleData.stops {
                if fuzzyMatch(stop.name, station.name) {
                    ids.insert(stop.id)
                }
            }
        }

        return ids
    }

    private func fuzzyMatch(_ str1: String, _ str2: String) -> Bool {
        let s1 = str1.lowercased().replacingOccurrences(of: " ", with: "")
        let s2 = str2.lowercased().replacingOccurrences(of: " ", with: "")
        return s1.contains(s2) || s2.contains(s1)
    }

    private func matchesDirection(trip: GTFSTrip, direction: TrainDirection) -> Bool {
        // Direction 0 is typically westbound (to Philly), 1 is eastbound (to Lindenwold)
        // But verify with headsign if available
        if let headsign = trip.headsign?.lowercased() {
            switch direction {
            case .eastbound:
                return headsign.contains("lindenwold") ||
                       headsign.contains("eastbound") ||
                       trip.directionId == 1
            case .westbound:
                return headsign.contains("15") ||
                       headsign.contains("16") ||
                       headsign.contains("locust") ||
                       headsign.contains("westbound") ||
                       headsign.contains("philadelphia") ||
                       trip.directionId == 0
            }
        }

        // Fall back to direction_id
        if let directionId = trip.directionId {
            switch direction {
            case .eastbound: return directionId == 1
            case .westbound: return directionId == 0
            }
        }

        return true // Include if we can't determine direction
    }

    private func getActiveServiceIds(for dateString: String, weekday: Int) -> Set<String> {
        var activeIds: Set<String> = []

        // Check calendar.txt for regular service
        for calendar in scheduleData.calendars {
            if calendar.startDate <= dateString && calendar.endDate >= dateString {
                if calendar.isActiveOn(weekday: weekday) {
                    activeIds.insert(calendar.serviceId)
                }
            }
        }

        // Check calendar_dates.txt for exceptions
        for calendarDate in scheduleData.calendarDates {
            if calendarDate.date == dateString {
                if calendarDate.exceptionType == 1 {
                    // Service added for this date
                    activeIds.insert(calendarDate.serviceId)
                } else if calendarDate.exceptionType == 2 {
                    // Service removed for this date
                    activeIds.remove(calendarDate.serviceId)
                }
            }
        }

        return activeIds
    }

    private func parseGTFSTime(_ timeString: String, relativeTo baseDate: Date) -> Date? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }

        var hours = components[0]
        let minutes = components[1]
        let seconds = components.count > 2 ? components[2] : 0

        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)

        // GTFS times can be > 24:00 for trips that go past midnight
        if hours >= 24 {
            hours -= 24
            if let currentDay = dateComponents.day {
                dateComponents.day = currentDay + 1
            }
        }

        dateComponents.hour = hours
        dateComponents.minute = minutes
        dateComponents.second = seconds

        return calendar.date(from: dateComponents)
    }
}
