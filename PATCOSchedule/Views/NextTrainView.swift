import SwiftUI
import ActivityKit

struct NextTrainView: View {
    let station: Station
    @EnvironmentObject var scheduleService: ScheduleService
    @StateObject private var liveActivityManager = LiveActivityManager()
    @State private var trainsByDirection: [String: UpcomingTrain] = [:]
    @State private var refreshTimer: Timer?

    var body: some View {
        let provider = scheduleService.provider

        VStack(spacing: 20) {
            // Station header
            VStack(spacing: 8) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                Text(station.displayName)
                    .font(.title)
                    .fontWeight(.bold)

                if scheduleService.isLoading {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            .padding(.top, 20)

            // Error state
            if let errorMessage = scheduleService.loadState.errorMessage {
                ScheduleErrorView(message: errorMessage) {
                    Task {
                        await scheduleService.loadSchedule()
                        refreshTrains()
                    }
                }
            } else if !scheduleService.isLoading {
                // Next trains cards
                HStack(spacing: 16) {
                    ForEach(provider.directions) { direction in
                        NextTrainCard(
                            direction: direction,
                            train: trainsByDirection[direction.id],
                            isTerminus: provider.isTerminus(station: station, direction: direction),
                            hasScheduleData: scheduleService.hasScheduleData,
                            onTrackTapped: { train in
                                startLiveActivity(direction: direction, train: train)
                            }
                        )
                    }
                }
                .padding(.horizontal)

                // Live Activity indicator
                if liveActivityManager.isActivityRunning {
                    LiveActivityIndicator {
                        Task {
                            await liveActivityManager.endActivity()
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()

            // Data source indicator
            if case .loaded(let source) = scheduleService.loadState {
                HStack(spacing: 4) {
                    Image(systemName: source == .live ? "antenna.radiowaves.left.and.right" : "internaldrive")
                        .font(.caption2)
                    Text(source.rawValue)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            // Last updated
            if let lastUpdated = scheduleService.lastUpdated {
                Text("Updated: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            liveActivityManager.setScheduleService(scheduleService)
            refreshTrains()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .refreshable {
            await scheduleService.loadSchedule()
            refreshTrains()
        }
    }

    private func refreshTrains() {
        let provider = scheduleService.provider
        var updated: [String: UpcomingTrain] = [:]
        for direction in provider.directions {
            updated[direction.id] = scheduleService.getNextTrain(for: station, direction: direction)
        }
        trainsByDirection = updated
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                refreshTrains()
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func startLiveActivity(direction: TransitDirection, train: UpcomingTrain) {
        guard liveActivityManager.isSupported else { return }
        liveActivityManager.startActivity(station: station, direction: direction, train: train)
    }
}

struct NextTrainCard: View {
    let direction: TransitDirection
    let train: UpcomingTrain?
    let isTerminus: Bool
    let hasScheduleData: Bool
    var onTrackTapped: ((UpcomingTrain) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            // Direction header
            HStack {
                Image(systemName: "arrow.left.circle.fill")
                Text(direction.shortLabel)
                    .font(.headline)
            }
            .foregroundColor(direction.color)

            Divider()

            if !hasScheduleData {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(.orange)
                Text("No data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if isTerminus {
                Text("Terminus")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Trains originate here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let train = train {
                Text("\(train.minutesUntilDeparture)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(train.minutesUntilDeparture <= 5 ? .orange : .primary)

                Text("minutes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(train.formattedDepartureTime)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if #available(iOS 16.1, *) {
                    Button {
                        onTrackTapped?(train)
                    } label: {
                        Label("Track", systemImage: "bell.badge")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                Text("No trains")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Destination
            Text(direction.destination)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

/// Indicator showing a Live Activity is running
struct LiveActivityIndicator: View {
    let onStop: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "bell.badge.fill")
                .foregroundColor(.blue)

            Text("Tracking on Lock Screen")
                .font(.subheadline)

            Spacer()

            Button("Stop") {
                onStop()
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Reusable error view for schedule loading issues
struct ScheduleErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Schedule Unavailable")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

#Preview {
    NextTrainView(station: PATCOProvider().stations[5])
        .environmentObject(ScheduleService())
}
