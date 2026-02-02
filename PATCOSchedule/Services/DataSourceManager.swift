import Foundation

/// Manages multiple data sources for PATCO schedule information
/// Priority: Live GTFS > PDF Schedules > Bundled Data
@MainActor
class DataSourceManager: ObservableObject {

    enum DataSourceType: String, CaseIterable {
        case liveGTFS = "Live GTFS"
        case pdfSchedule = "PDF Schedule"
        case bundled = "Bundled Data"
        case specialSchedule = "Special Schedule"
    }

    struct DataSourceStatus {
        let type: DataSourceType
        let lastUpdated: Date?
        let lastChecked: Date?
        let isAvailable: Bool
        let error: String?
    }

    // MARK: - Published Properties

    @Published var activeSource: DataSourceType = .bundled
    @Published var sourceStatuses: [DataSourceType: DataSourceStatus] = [:]
    @Published var specialSchedules: [PDFScheduleParser.SpecialScheduleInfo] = []
    @Published var lastUpdateCheck: Date?

    // MARK: - Private Properties

    private let gtfsParser = GTFSParser()
    private let pdfParser = PDFScheduleParser()

    // MARK: - Initialization

    init() {
        // Initialize with bundled data as available
        sourceStatuses[.bundled] = DataSourceStatus(
            type: .bundled,
            lastUpdated: nil, // Bundled is always current
            lastChecked: Date(),
            isAvailable: true,
            error: nil
        )
    }

    // MARK: - Data Fetching

    /// Fetch the best available schedule data
    func fetchBestAvailableData() async -> (ScheduleData, DataSourceType) {
        // First, always have bundled data ready as fallback
        let bundledData = BundledScheduleData.generateScheduleData()

        // Check for special schedules first
        await checkForSpecialSchedules()

        // Try live GTFS
        do {
            let gtfsData = try await gtfsParser.downloadAndParseGTFS()
            if gtfsData.isLoaded {
                updateSourceStatus(.liveGTFS, available: true, lastUpdated: Date())
                activeSource = .liveGTFS
                return (gtfsData, .liveGTFS)
            }
        } catch {
            updateSourceStatus(.liveGTFS, available: false, error: error.localizedDescription)
            print("GTFS fetch failed: \(error)")
        }

        // Try PDF schedule as fallback
        do {
            let pdfData = try await pdfParser.fetchScheduleFromPDF()
            if pdfData.isLoaded {
                updateSourceStatus(.pdfSchedule, available: true, lastUpdated: Date())
                activeSource = .pdfSchedule
                return (pdfData, .pdfSchedule)
            }
        } catch {
            updateSourceStatus(.pdfSchedule, available: false, error: error.localizedDescription)
            print("PDF fetch failed: \(error)")
        }

        // Fall back to bundled data
        activeSource = .bundled
        return (bundledData, .bundled)
    }

    /// Check for updates without downloading full data
    func checkForUpdates() async -> Bool {
        lastUpdateCheck = Date()
        var hasUpdates = false

        // Check GTFS updates
        do {
            let updateInfo = try await gtfsParser.checkGTFSUpdateInfo()
            let cachedDate = gtfsParser.getCachedGTFSDate()

            if let remoteDate = updateInfo.lastModified,
               let localDate = cachedDate,
               remoteDate > localDate {
                hasUpdates = true
                sourceStatuses[.liveGTFS] = DataSourceStatus(
                    type: .liveGTFS,
                    lastUpdated: remoteDate,
                    lastChecked: Date(),
                    isAvailable: true,
                    error: nil
                )
            }
        } catch {
            print("Failed to check GTFS updates: \(error)")
        }

        // Check for special schedules
        let newSpecials = await pdfParser.checkForSpecialSchedules()
        if !newSpecials.isEmpty && newSpecials.count != specialSchedules.count {
            hasUpdates = true
            specialSchedules = newSpecials
        }

        return hasUpdates
    }

    /// Check for special schedules
    func checkForSpecialSchedules() async {
        let specials = await pdfParser.checkForSpecialSchedules()
        specialSchedules = specials

        if !specials.isEmpty {
            // Check if any special schedule is currently active
            let now = Date()
            let activeSpecials = specials.filter { special in
                if let start = special.effectiveDate, let end = special.expirationDate {
                    return now >= start && now <= end
                } else if let start = special.effectiveDate {
                    return now >= start
                }
                return false
            }

            if !activeSpecials.isEmpty {
                updateSourceStatus(.specialSchedule, available: true, lastUpdated: Date())
            }
        }
    }

    /// Get GTFS update info
    func getGTFSUpdateInfo() async -> GTFSParser.GTFSUpdateInfo? {
        do {
            return try await gtfsParser.checkGTFSUpdateInfo()
        } catch {
            return nil
        }
    }

    // MARK: - Source Status Management

    private func updateSourceStatus(_ type: DataSourceType, available: Bool, lastUpdated: Date? = nil, error: String? = nil) {
        sourceStatuses[type] = DataSourceStatus(
            type: type,
            lastUpdated: lastUpdated,
            lastChecked: Date(),
            isAvailable: available,
            error: error
        )
    }

    /// Get a human-readable summary of data source status
    func getStatusSummary() -> String {
        var lines: [String] = []

        lines.append("Active Source: \(activeSource.rawValue)")

        if let lastCheck = lastUpdateCheck {
            let formatter = RelativeDateTimeFormatter()
            lines.append("Last checked: \(formatter.localizedString(for: lastCheck, relativeTo: Date()))")
        }

        for (type, status) in sourceStatuses.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            var statusLine = "\(type.rawValue): "
            statusLine += status.isAvailable ? "Available" : "Unavailable"

            if let lastUpdated = status.lastUpdated {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                statusLine += " (Updated: \(formatter.string(from: lastUpdated)))"
            }

            if let error = status.error {
                statusLine += " - \(error)"
            }

            lines.append(statusLine)
        }

        if !specialSchedules.isEmpty {
            lines.append("\nSpecial Schedules:")
            for special in specialSchedules {
                lines.append("  - \(special.name)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Manual Source Selection

    /// Force use of a specific data source
    func useDataSource(_ type: DataSourceType) async -> ScheduleData? {
        switch type {
        case .liveGTFS:
            do {
                let data = try await gtfsParser.downloadAndParseGTFS()
                if data.isLoaded {
                    activeSource = .liveGTFS
                    return data
                }
            } catch {
                print("Failed to use GTFS source: \(error)")
            }

        case .pdfSchedule:
            do {
                let data = try await pdfParser.fetchScheduleFromPDF()
                if data.isLoaded {
                    activeSource = .pdfSchedule
                    return data
                }
            } catch {
                print("Failed to use PDF source: \(error)")
            }

        case .bundled:
            activeSource = .bundled
            return BundledScheduleData.generateScheduleData()

        case .specialSchedule:
            // For special schedules, try to fetch from the special schedule PDF if available
            if let special = specialSchedules.first(where: { $0.pdfURL != nil }),
               let pdfURL = special.pdfURL {
                do {
                    let data = try await pdfParser.downloadAndParsePDF(from: pdfURL)
                    if data.isLoaded {
                        activeSource = .specialSchedule
                        return data
                    }
                } catch {
                    print("Failed to load special schedule: \(error)")
                }
            }
        }

        return nil
    }
}
