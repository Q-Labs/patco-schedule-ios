import Foundation
import PDFKit

/// Configuration supplied by a TransitProvider for PDF-based schedule parsing.
struct PDFParserConfig {
    let scheduleURLs: [URL]
    let schedulePage: URL?
    let scheduleDomain: String
    let directionPatterns: [String: [String]]
    let stops: [GTFSStop]
    let cumulativeTravelTimes: [Int]
    let routeId: String
    let westboundHeadsign: String
    let eastboundHeadsign: String
}

/// Parser for transit schedule PDFs as a fallback data source.
class PDFScheduleParser {

    private let config: PDFParserConfig

    init(config: PDFParserConfig) {
        self.config = config
    }

    enum PDFParserError: Error, LocalizedError {
        case downloadFailed(Error)
        case pdfLoadFailed
        case noTextContent
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let error):
                return "Failed to download PDF: \(error.localizedDescription)"
            case .pdfLoadFailed:
                return "Failed to load PDF document"
            case .noTextContent:
                return "No text content found in PDF"
            case .parseError(let message):
                return "Parse error: \(message)"
            }
        }
    }

    // MARK: - Special Schedule Detection

    struct SpecialScheduleInfo {
        let name: String
        let effectiveDate: Date?
        let expirationDate: Date?
        let pdfURL: URL?
        let description: String?
    }

    /// Check for special schedules (holidays, service changes, etc.)
    func checkForSpecialSchedules() async -> [SpecialScheduleInfo] {
        var specialSchedules: [SpecialScheduleInfo] = []

        guard let schedulePage = config.schedulePage else { return specialSchedules }

        do {
            let (data, response) = try await URLSession.shared.data(from: schedulePage)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return specialSchedules
            }

            // Parse HTML for special schedule mentions
            specialSchedules = parseSchedulePageForSpecials(html: html)

        } catch {
            print("Failed to check for special schedules: \(error)")
        }

        return specialSchedules
    }

    /// Parse the schedule page HTML to find special schedule announcements
    private func parseSchedulePageForSpecials(html: String) -> [SpecialScheduleInfo] {
        var specials: [SpecialScheduleInfo] = []

        // Look for common patterns in transit schedule pages
        let patterns = [
            "holiday schedule",
            "special schedule",
            "modified schedule",
            "service change",
            "temporary schedule",
            "revised schedule"
        ]

        let lowercaseHTML = html.lowercased()

        for pattern in patterns {
            if lowercaseHTML.contains(pattern) {
                // Try to extract the context around the pattern
                if let range = lowercaseHTML.range(of: pattern) {
                    let startIndex = html.index(range.lowerBound, offsetBy: -100, limitedBy: html.startIndex) ?? html.startIndex
                    let endIndex = html.index(range.upperBound, offsetBy: 200, limitedBy: html.endIndex) ?? html.endIndex
                    let context = String(html[startIndex..<endIndex])

                    // Try to find PDF links in the context
                    let pdfURL = extractPDFURL(from: context)

                    // Try to extract dates
                    let dates = extractDates(from: context)

                    let special = SpecialScheduleInfo(
                        name: pattern.capitalized,
                        effectiveDate: dates.start,
                        expirationDate: dates.end,
                        pdfURL: pdfURL,
                        description: context.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    specials.append(special)
                }
            }
        }

        return specials
    }

    /// Extract PDF URL from HTML context
    private func extractPDFURL(from html: String) -> URL? {
        // Look for href attributes pointing to PDFs
        let pdfPattern = #"href=[\"']([^\"']*\.pdf)[\"']"#
        guard let regex = try? NSRegularExpression(pattern: pdfPattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let urlRange = Range(match.range(at: 1), in: html) {
            let urlString = String(html[urlRange])

            // Handle relative URLs
            if urlString.hasPrefix("http") {
                return URL(string: urlString)
            } else if urlString.hasPrefix("/") {
                return URL(string: "\(config.scheduleDomain)\(urlString)")
            } else {
                return URL(string: "\(config.scheduleDomain)/schedules/\(urlString)")
            }
        }

        return nil
    }

    /// Extract dates from text
    private func extractDates(from text: String) -> (start: Date?, end: Date?) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")

        // Common date formats
        let formats = [
            "MMMM d, yyyy",
            "MMM d, yyyy",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MMMM d",
            "MMM d"
        ]

        var foundDates: [Date] = []

        // Simple date pattern matching
        let datePattern = #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}(?:,?\s+\d{4})?\b|\b\d{1,2}/\d{1,2}/\d{2,4}\b"#

        guard let regex = try? NSRegularExpression(pattern: datePattern, options: .caseInsensitive) else {
            return (nil, nil)
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        for match in matches {
            if let matchRange = Range(match.range, in: text) {
                let dateString = String(text[matchRange])

                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        foundDates.append(date)
                        break
                    }
                }
            }
        }

        foundDates.sort()

        return (foundDates.first, foundDates.count > 1 ? foundDates.last : nil)
    }

    // MARK: - PDF Download and Parsing

    /// Download and parse a schedule PDF
    func downloadAndParsePDF(from url: URL) async throws -> ScheduleData {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PDFParserError.downloadFailed(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }

        return try parsePDFData(data)
    }

    /// Try to fetch schedule from any available PDF source
    func fetchScheduleFromPDF() async throws -> ScheduleData {
        let urlsToTry = config.scheduleURLs

        var lastError: Error = PDFParserError.pdfLoadFailed

        for url in urlsToTry {
            do {
                let scheduleData = try await downloadAndParsePDF(from: url)
                if scheduleData.isLoaded {
                    return scheduleData
                }
            } catch {
                lastError = error
                print("Failed to parse PDF from \(url): \(error)")
                continue
            }
        }

        throw lastError
    }

    /// Parse PDF data into schedule data
    func parsePDFData(_ data: Data) throws -> ScheduleData {
        guard let pdfDocument = PDFDocument(data: data) else {
            throw PDFParserError.pdfLoadFailed
        }

        var fullText = ""

        // Extract text from all pages
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }
            fullText += pageText + "\n"
        }

        guard !fullText.isEmpty else {
            throw PDFParserError.noTextContent
        }

        // Parse the extracted text into schedule data
        return try parseScheduleText(fullText)
    }

    /// Parse schedule text extracted from PDF
    private func parseScheduleText(_ text: String) throws -> ScheduleData {
        var scheduleData = ScheduleData()

        // Use provider-supplied stops as our reference
        scheduleData.stops = config.stops
        scheduleData.calendars = BundledScheduleData.calendars

        // Extract departure times from the text
        let departureTimes = extractDepartureTimes(from: text)

        if departureTimes.westbound.isEmpty && departureTimes.eastbound.isEmpty {
            // If we couldn't parse times, return bundled data as fallback
            return ScheduleData()
        }

        // Generate trips and stop times from extracted departures
        var allTrips: [GTFSTrip] = []
        var allStopTimes: [GTFSStopTime] = []

        // Generate weekday schedule from extracted times
        let (weekdayTrips, weekdayStopTimes) = generateTripsFromDepartures(
            westboundDepartures: departureTimes.westbound,
            eastboundDepartures: departureTimes.eastbound,
            serviceId: "WEEKDAY"
        )
        allTrips.append(contentsOf: weekdayTrips)
        allStopTimes.append(contentsOf: weekdayStopTimes)

        // Use same times for weekend with reduced frequency (take every other)
        let weekendWestbound = Array(departureTimes.westbound.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element })
        let weekendEastbound = Array(departureTimes.eastbound.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element })

        let (saturdayTrips, saturdayStopTimes) = generateTripsFromDepartures(
            westboundDepartures: weekendWestbound,
            eastboundDepartures: weekendEastbound,
            serviceId: "SATURDAY"
        )
        allTrips.append(contentsOf: saturdayTrips)
        allStopTimes.append(contentsOf: saturdayStopTimes)

        let (sundayTrips, sundayStopTimes) = generateTripsFromDepartures(
            westboundDepartures: weekendWestbound,
            eastboundDepartures: weekendEastbound,
            serviceId: "SUNDAY"
        )
        allTrips.append(contentsOf: sundayTrips)
        allStopTimes.append(contentsOf: sundayStopTimes)

        scheduleData.trips = allTrips
        scheduleData.stopTimes = allStopTimes

        return scheduleData
    }

    /// Extract departure times from schedule text
    private func extractDepartureTimes(from text: String) -> (westbound: [String], eastbound: [String]) {
        var westboundTimes: [String] = []
        var eastboundTimes: [String] = []

        // Time pattern: matches HH:MM in 12 or 24 hour format
        let timePattern = #"\b([01]?\d|2[0-3]):([0-5]\d)\s*(AM|PM|am|pm)?\b"#

        guard let regex = try? NSRegularExpression(pattern: timePattern, options: []) else {
            return ([], [])
        }

        let lines = text.components(separatedBy: .newlines)

        var currentDirection: String?

        for line in lines {
            let lowercaseLine = line.lowercased()

            // Detect direction changes using provider-supplied patterns
            for (dirId, patterns) in config.directionPatterns {
                if patterns.contains(where: { lowercaseLine.contains($0) }) {
                    currentDirection = dirId
                    break
                }
            }

            // Extract times from this line
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, options: [], range: range)

            for match in matches {
                if let matchRange = Range(match.range, in: line) {
                    var timeString = String(line[matchRange])

                    // Convert to 24-hour format if needed
                    timeString = convertTo24Hour(timeString)

                    if let direction = currentDirection {
                        if direction == "westbound" {
                            westboundTimes.append(timeString)
                        } else {
                            eastboundTimes.append(timeString)
                        }
                    }
                }
            }
        }

        // Remove duplicates and sort
        westboundTimes = Array(Set(westboundTimes)).sorted()
        eastboundTimes = Array(Set(eastboundTimes)).sorted()

        return (westboundTimes, eastboundTimes)
    }

    /// Convert time string to 24-hour format
    private func convertTo24Hour(_ time: String) -> String {
        let components = time.uppercased().components(separatedBy: CharacterSet(charactersIn: ": "))

        guard components.count >= 2,
              var hour = Int(components[0]),
              let minute = Int(components[1].prefix(2)) else {
            return time
        }

        let isPM = time.uppercased().contains("PM")
        let isAM = time.uppercased().contains("AM")

        if isPM && hour < 12 {
            hour += 12
        } else if isAM && hour == 12 {
            hour = 0
        }

        return String(format: "%02d:%02d", hour, minute)
    }

    /// Generate trips and stop times from departure lists
    private func generateTripsFromDepartures(
        westboundDepartures: [String],
        eastboundDepartures: [String],
        serviceId: String
    ) -> ([GTFSTrip], [GTFSStopTime]) {
        var trips: [GTFSTrip] = []
        var stopTimes: [GTFSStopTime] = []

        let travelTimes = config.cumulativeTravelTimes
        let stops = config.stops

        // Generate westbound trips
        for (index, departureTime) in westboundDepartures.enumerated() {
            let tripId = "\(serviceId)_PDF_WB_\(index)"
            let trip = GTFSTrip(
                id: tripId,
                routeId: config.routeId,
                serviceId: serviceId,
                headsign: config.westboundHeadsign,
                directionId: 0
            )
            trips.append(trip)

            // Generate stop times
            guard let startMinutes = parseTimeToMinutes(departureTime) else { continue }

            for (sequence, stop) in stops.enumerated() {
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
        }

        // Generate eastbound trips
        let reversedStops = stops.reversed()
        let reversedTravelTimes = travelTimes.reversed().map { travelTimes.last! - $0 }

        for (index, departureTime) in eastboundDepartures.enumerated() {
            let tripId = "\(serviceId)_PDF_EB_\(index)"
            let trip = GTFSTrip(
                id: tripId,
                routeId: config.routeId,
                serviceId: serviceId,
                headsign: config.eastboundHeadsign,
                directionId: 1
            )
            trips.append(trip)

            guard let startMinutes = parseTimeToMinutes(departureTime) else { continue }

            for (sequence, stop) in reversedStops.enumerated() {
                let arrivalMinutes = startMinutes + Array(reversedTravelTimes)[sequence]
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
        }

        return (trips, stopTimes)
    }

    private func parseTimeToMinutes(_ time: String) -> Int? {
        let components = time.split(separator: ":").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }
        return components[0] * 60 + components[1]
    }

    private func minutesToTimeString(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d:00", hours, mins)
    }

    // MARK: - PDF Update Check

    /// Check when the PDF was last modified
    func checkPDFLastModified(url: URL) async -> Date? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified") else {
                return nil
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.date(from: lastModifiedString)

        } catch {
            return nil
        }
    }
}
