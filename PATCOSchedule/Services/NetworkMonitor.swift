import Foundation
import Network

/// Monitors network connectivity and quality
@MainActor
class NetworkMonitor: ObservableObject {

    enum NetworkStatus: Equatable {
        case unknown
        case disconnected
        case connected(quality: ConnectionQuality)

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }

        var canFetchData: Bool {
            if case .connected(let quality) = self {
                return quality != .poor
            }
            return false
        }
    }

    enum ConnectionQuality {
        case poor       // Cellular with weak signal or constrained
        case moderate   // Cellular or slow wifi
        case good       // Strong wifi or ethernet

        var description: String {
            switch self {
            case .poor: return "Poor"
            case .moderate: return "Moderate"
            case .good: return "Good"
            }
        }
    }

    @Published var status: NetworkStatus = .unknown
    @Published var statusMessage: String?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private var connectionRestoredCallback: (() -> Void)?

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Register a callback to be called when connection is restored
    func onConnectionRestored(_ callback: @escaping () -> Void) {
        connectionRestoredCallback = callback
    }

    /// Clear the connection restored callback
    func clearConnectionRestoredCallback() {
        connectionRestoredCallback = nil
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let previousStatus = status

        if path.status == .satisfied {
            let quality = determineConnectionQuality(path)
            status = .connected(quality: quality)

            switch quality {
            case .poor:
                statusMessage = "Connection is weak. Data refresh may be slow."
            case .moderate:
                statusMessage = nil
            case .good:
                statusMessage = nil
            }

            // If we were disconnected and now connected with good enough connection
            if !previousStatus.isConnected && quality != .poor {
                connectionRestoredCallback?()
            }
        } else {
            status = .disconnected
            statusMessage = "No internet connection"
        }
    }

    private func determineConnectionQuality(_ path: NWPath) -> ConnectionQuality {
        // Check if connection is constrained (e.g., Low Data Mode)
        if path.isConstrained {
            return .poor
        }

        // Check if connection is expensive (cellular)
        if path.isExpensive {
            // Cellular connection - check if we have multiple interfaces (better signal)
            if path.availableInterfaces.count > 1 {
                return .moderate
            }
            return .moderate
        }

        // WiFi or Ethernet
        if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
            return .good
        }

        // Default to moderate for unknown types
        return .moderate
    }
}
