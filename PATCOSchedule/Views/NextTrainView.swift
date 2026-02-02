import SwiftUI

struct NextTrainView: View {
    let station: Station
    @EnvironmentObject var scheduleService: ScheduleService
    @State private var eastboundTrain: UpcomingTrain?
    @State private var westboundTrain: UpcomingTrain?
    @State private var refreshTimer: Timer?

    var body: some View {
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
                    // Westbound (to Philly)
                    NextTrainCard(
                        direction: .westbound,
                        train: westboundTrain,
                        stationOrder: station.order,
                        hasScheduleData: scheduleService.hasScheduleData
                    )

                    // Eastbound (to Lindenwold)
                    NextTrainCard(
                        direction: .eastbound,
                        train: eastboundTrain,
                        stationOrder: station.order,
                        hasScheduleData: scheduleService.hasScheduleData
                    )
                }
                .padding(.horizontal)
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
        eastboundTrain = scheduleService.getNextTrain(for: station, direction: .eastbound)
        westboundTrain = scheduleService.getNextTrain(for: station, direction: .westbound)
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
}

struct NextTrainCard: View {
    let direction: TrainDirection
    let train: UpcomingTrain?
    let stationOrder: Int
    let hasScheduleData: Bool

    var isTerminus: Bool {
        switch direction {
        case .eastbound:
            return stationOrder == 0 // Lindenwold
        case .westbound:
            return stationOrder == 13 // 15th-16th
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Direction header
            HStack {
                Image(systemName: direction == .westbound ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                Text(direction == .westbound ? "To Philly" : "To NJ")
                    .font(.headline)
            }
            .foregroundColor(direction == .westbound ? .purple : .green)

            Divider()

            if !hasScheduleData {
                // No schedule data available
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
                // Minutes
                Text("\(train.minutesUntilDeparture)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(train.minutesUntilDeparture <= 5 ? .orange : .primary)

                Text("minutes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Departure time
                Text(train.formattedDepartureTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    NextTrainView(station: Station.allStations[5])
        .environmentObject(ScheduleService())
}
