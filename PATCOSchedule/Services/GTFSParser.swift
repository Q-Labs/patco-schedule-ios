import Foundation
import Compression

class GTFSParser {

    enum ParserError: Error, LocalizedError {
        case invalidURL
        case downloadFailed(Error)
        case unzipFailed
        case parseError(String)
        case fileNotFound(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid GTFS URL"
            case .downloadFailed(let error):
                return "Failed to download GTFS data: \(error.localizedDescription)"
            case .unzipFailed:
                return "Failed to unzip GTFS data"
            case .parseError(let message):
                return "Parse error: \(message)"
            case .fileNotFound(let filename):
                return "Required file not found: \(filename)"
            }
        }
    }

    static let gtfsURL = URL(string: "https://www.ridepatco.org/developers/PortAuthorityTransitCorporation.zip")!

    // MARK: - Public Methods

    func downloadAndParseGTFS() async throws -> ScheduleData {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let gtfsDir = cacheDir.appendingPathComponent("gtfs_data")

        // Check if we need to refresh (refresh if older than 24 hours)
        let shouldRefresh = shouldRefreshCache(at: gtfsDir)

        if shouldRefresh {
            // Download and extract
            let zipData = try await downloadGTFSZip()
            try await extractZip(data: zipData, to: gtfsDir)
        }

        // Parse the GTFS files
        return try parseGTFSDirectory(at: gtfsDir)
    }

    func parseGTFSDirectory(at url: URL) throws -> ScheduleData {
        var scheduleData = ScheduleData()

        // Parse stops.txt
        let stopsURL = url.appendingPathComponent("stops.txt")
        if FileManager.default.fileExists(atPath: stopsURL.path) {
            scheduleData.stops = try parseCSV(at: stopsURL, as: GTFSStop.self)
        }

        // Parse routes.txt
        let routesURL = url.appendingPathComponent("routes.txt")
        if FileManager.default.fileExists(atPath: routesURL.path) {
            scheduleData.routes = try parseCSV(at: routesURL, as: GTFSRoute.self)
        }

        // Parse trips.txt
        let tripsURL = url.appendingPathComponent("trips.txt")
        if FileManager.default.fileExists(atPath: tripsURL.path) {
            scheduleData.trips = try parseCSV(at: tripsURL, as: GTFSTrip.self)
        }

        // Parse stop_times.txt
        let stopTimesURL = url.appendingPathComponent("stop_times.txt")
        if FileManager.default.fileExists(atPath: stopTimesURL.path) {
            scheduleData.stopTimes = try parseCSV(at: stopTimesURL, as: GTFSStopTime.self)
        }

        // Parse calendar.txt
        let calendarURL = url.appendingPathComponent("calendar.txt")
        if FileManager.default.fileExists(atPath: calendarURL.path) {
            scheduleData.calendars = try parseCSV(at: calendarURL, as: GTFSCalendar.self)
        }

        // Parse calendar_dates.txt
        let calendarDatesURL = url.appendingPathComponent("calendar_dates.txt")
        if FileManager.default.fileExists(atPath: calendarDatesURL.path) {
            scheduleData.calendarDates = try parseCSV(at: calendarDatesURL, as: GTFSCalendarDate.self)
        }

        return scheduleData
    }

    // MARK: - Private Methods

    private func shouldRefreshCache(at url: URL) -> Bool {
        let fileManager = FileManager.default
        let stopsFile = url.appendingPathComponent("stops.txt")

        guard fileManager.fileExists(atPath: stopsFile.path),
              let attributes = try? fileManager.attributesOfItem(atPath: stopsFile.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return true
        }

        // Refresh if older than 24 hours
        let hoursSinceModification = Date().timeIntervalSince(modificationDate) / 3600
        return hoursSinceModification > 24
    }

    private func downloadGTFSZip() async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: Self.gtfsURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ParserError.downloadFailed(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }

        return data
    }

    private func extractZip(data: Data, to destination: URL) async throws {
        let fileManager = FileManager.default

        // Remove existing directory
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        // Create directory
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        // Write zip file temporarily
        let tempZipURL = destination.appendingPathComponent("temp.zip")
        try data.write(to: tempZipURL)

        // Use Process to unzip (iOS doesn't have built-in zip support, so we'll parse manually)
        // For iOS, we'll use a simple zip extraction
        try await unzipFile(at: tempZipURL, to: destination)

        // Clean up temp file
        try? fileManager.removeItem(at: tempZipURL)
    }

    private func unzipFile(at sourceURL: URL, to destinationURL: URL) async throws {
        // Simple zip extraction using FileHandle and manual parsing
        // For a production app, you'd use a proper zip library like ZIPFoundation
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", sourceURL.path, "-d", destinationURL.path]
        process.standardOutput = nil
        process.standardError = nil

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ParserError.unzipFailed
        }
    }

    private func parseCSV<T: Decodable>(at url: URL, as type: T.Type) throws -> [T] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard lines.count > 1 else {
            return []
        }

        let headers = parseCSVLine(lines[0])
        var results: [T] = []

        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])

            guard values.count == headers.count else {
                continue
            }

            var dict: [String: Any] = [:]
            for (index, header) in headers.enumerated() {
                let value = values[index]
                // Try to convert to appropriate type
                if let intValue = Int(value) {
                    dict[header] = intValue
                } else if let doubleValue = Double(value) {
                    dict[header] = doubleValue
                } else {
                    dict[header] = value
                }
            }

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dict)
                let decoded = try JSONDecoder().decode(T.self, from: jsonData)
                results.append(decoded)
            } catch {
                // Skip malformed rows
                continue
            }
        }

        return results
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }

        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }
}
