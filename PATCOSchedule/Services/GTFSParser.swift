import Foundation
import Compression

class GTFSParser {

    enum ParserError: Error, LocalizedError {
        case invalidURL
        case downloadFailed(Error)
        case unzipFailed(String)
        case parseError(String)
        case fileNotFound(String)
        case invalidZipFormat

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid GTFS URL"
            case .downloadFailed(let error):
                return "Failed to download GTFS data: \(error.localizedDescription)"
            case .unzipFailed(let message):
                return "Failed to unzip GTFS data: \(message)"
            case .parseError(let message):
                return "Parse error: \(message)"
            case .fileNotFound(let filename):
                return "Required file not found: \(filename)"
            case .invalidZipFormat:
                return "Invalid ZIP file format"
            }
        }
    }

    let gtfsURL: URL

    init(gtfsURL: URL) {
        self.gtfsURL = gtfsURL
    }

    // MARK: - GTFS Update Info

    struct GTFSUpdateInfo {
        let lastModified: Date?
        let etag: String?
        let contentLength: Int64?
    }

    /// Check when the GTFS data was last updated without downloading the full file
    func checkGTFSUpdateInfo() async throws -> GTFSUpdateInfo {
        var request = URLRequest(url: self.gtfsURL)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ParserError.downloadFailed(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }

        var lastModified: Date?
        if let lastModifiedString = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            lastModified = formatter.date(from: lastModifiedString)
        }

        let etag = httpResponse.value(forHTTPHeaderField: "ETag")
        let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "0")

        return GTFSUpdateInfo(lastModified: lastModified, etag: etag, contentLength: contentLength)
    }

    /// Check if remote GTFS data is newer than our cached version
    func isRemoteGTFSNewer(than localDate: Date?) async -> Bool {
        guard let localDate = localDate else { return true }

        do {
            let updateInfo = try await checkGTFSUpdateInfo()
            if let remoteDate = updateInfo.lastModified {
                return remoteDate > localDate
            }
        } catch {
            print("Failed to check GTFS update info: \(error)")
        }

        // If we can't determine, assume it might be newer
        return true
    }

    // MARK: - Public Methods

    func downloadAndParseGTFS() async throws -> ScheduleData {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let gtfsDir = cacheDir.appendingPathComponent("gtfs_data")

        // Check if we need to refresh (refresh if older than 24 hours or remote is newer)
        let shouldRefresh = await shouldRefreshCache(at: gtfsDir)

        if shouldRefresh {
            // Download and extract
            let zipData = try await downloadGTFSZip()
            try extractZipData(zipData, to: gtfsDir)
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

    // MARK: - Cache Management

    private func shouldRefreshCache(at url: URL) async -> Bool {
        let fileManager = FileManager.default
        let stopsFile = url.appendingPathComponent("stops.txt")

        guard fileManager.fileExists(atPath: stopsFile.path),
              let attributes = try? fileManager.attributesOfItem(atPath: stopsFile.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return true
        }

        // Refresh if older than 24 hours
        let hoursSinceModification = Date().timeIntervalSince(modificationDate) / 3600
        if hoursSinceModification > 24 {
            // Check if remote is actually newer before downloading
            return await isRemoteGTFSNewer(than: modificationDate)
        }

        return false
    }

    func getCachedGTFSDate() -> Date? {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let stopsFile = cacheDir.appendingPathComponent("gtfs_data/stops.txt")

        guard let attributes = try? fileManager.attributesOfItem(atPath: stopsFile.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }

        return modificationDate
    }

    // MARK: - Download

    private func downloadGTFSZip() async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: self.gtfsURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ParserError.downloadFailed(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }

        return data
    }

    // MARK: - iOS-Compatible ZIP Extraction

    /// Extract ZIP data using pure Swift (iOS compatible)
    private func extractZipData(_ data: Data, to destination: URL) throws {
        let fileManager = FileManager.default

        // Remove existing directory
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        // Create directory
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        // Parse ZIP file structure and extract
        try parseAndExtractZip(data: data, to: destination)
    }

    /// Parse ZIP file format and extract files
    /// ZIP format: https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
    private func parseAndExtractZip(data: Data, to destination: URL) throws {
        var offset = 0
        let fileManager = FileManager.default

        while offset < data.count - 4 {
            // Check for local file header signature (0x04034b50)
            let signature = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }

            if signature == 0x04034b50 {
                // Local file header
                guard offset + 30 <= data.count else {
                    throw ParserError.invalidZipFormat
                }

                let compressionMethod = data.subdata(in: offset+8..<offset+10).withUnsafeBytes { $0.load(as: UInt16.self) }
                let compressedSize = Int(data.subdata(in: offset+18..<offset+22).withUnsafeBytes { $0.load(as: UInt32.self) })
                let uncompressedSize = Int(data.subdata(in: offset+22..<offset+26).withUnsafeBytes { $0.load(as: UInt32.self) })
                let fileNameLength = Int(data.subdata(in: offset+26..<offset+28).withUnsafeBytes { $0.load(as: UInt16.self) })
                let extraFieldLength = Int(data.subdata(in: offset+28..<offset+30).withUnsafeBytes { $0.load(as: UInt16.self) })

                let fileNameStart = offset + 30
                let fileNameEnd = fileNameStart + fileNameLength

                guard fileNameEnd <= data.count else {
                    throw ParserError.invalidZipFormat
                }

                let fileNameData = data.subdata(in: fileNameStart..<fileNameEnd)
                guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                    offset = fileNameEnd + extraFieldLength + compressedSize
                    continue
                }

                let dataStart = fileNameEnd + extraFieldLength
                let dataEnd = dataStart + compressedSize

                guard dataEnd <= data.count else {
                    throw ParserError.invalidZipFormat
                }

                // Skip directories and hidden files
                if !fileName.hasSuffix("/") && !fileName.hasPrefix("__MACOSX") && !fileName.hasPrefix(".") {
                    let compressedData = data.subdata(in: dataStart..<dataEnd)
                    var extractedData: Data

                    if compressionMethod == 0 {
                        // Stored (no compression)
                        extractedData = compressedData
                    } else if compressionMethod == 8 {
                        // Deflate compression
                        extractedData = try decompressDeflate(compressedData, expectedSize: uncompressedSize)
                    } else {
                        print("Unsupported compression method \(compressionMethod) for \(fileName)")
                        offset = dataEnd
                        continue
                    }

                    // Get just the filename without any directory path in the zip
                    let destFileName = (fileName as NSString).lastPathComponent
                    let fileURL = destination.appendingPathComponent(destFileName)

                    // Create parent directory if needed
                    let parentDir = fileURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: parentDir.path) {
                        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    }

                    try extractedData.write(to: fileURL)
                }

                offset = dataEnd
            } else if signature == 0x02014b50 {
                // Central directory header - we're done with file entries
                break
            } else if signature == 0x06054b50 {
                // End of central directory - we're done
                break
            } else {
                // Unknown signature, try to skip ahead
                offset += 1
            }
        }
    }

    /// Decompress deflate-compressed data using Apple's Compression framework
    private func decompressDeflate(_ data: Data, expectedSize: Int) throws -> Data {
        // Use a reasonable buffer size
        let bufferSize = max(expectedSize, 65536)
        var decompressedData = Data(count: bufferSize)

        let decompressedSize = decompressedData.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { srcBuffer in
                compression_decode_buffer(
                    destBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    bufferSize,
                    srcBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decompressedSize > 0 else {
            throw ParserError.unzipFailed("Decompression failed")
        }

        decompressedData.count = decompressedSize
        return decompressedData
    }

    // MARK: - CSV Parsing

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
