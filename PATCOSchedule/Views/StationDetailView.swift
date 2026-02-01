import SwiftUI

struct StationDetailView: View {
    let station: Station
    @EnvironmentObject var scheduleService: ScheduleService
    @State private var selectedDirection: TrainDirection = .westbound
    @State private var upcomingTrains: [UpcomingTrain] = []
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Direction Picker
            Picker("Direction", selection: $selectedDirection) {
                ForEach(TrainDirection.allCases) { direction in
                    Text(direction.destination)
                        .tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if let errorMessage = scheduleService.loadState.errorMessage {
                // Error state
                Spacer()
                ScheduleErrorView(message: errorMessage) {
                    Task {
                        await scheduleService.loadSchedule()
                        refreshTrains()
                    }
                }
                Spacer()
            } else if scheduleService.isLoading {
                Spacer()
                ProgressView("Loading schedule...")
                Spacer()
            } else if !scheduleService.hasScheduleData {
                // No schedule data loaded
                Spacer()
                ContentUnavailableView(
                    "Schedule Data Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Unable to load train schedule. Please try again later.")
                )
                Spacer()
            } else if upcomingTrains.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Upcoming Trains",
                    systemImage: "tram",
                    description: Text("No trains scheduled in this direction from \(station.displayName) at this time.")
                )
                Spacer()
            } else {
                List {
                    Section {
                        ForEach(upcomingTrains) { train in
                            TrainRowView(train: train)
                        }
                    } header: {
                        Text("Next Trains to \(selectedDirection.destination)")
                    } footer: {
                        if case .loaded(let source) = scheduleService.loadState {
                            Text("Data source: \(source.rawValue)")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(station.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    refreshTrains()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(scheduleService.isLoading)
            }
        }
        .onAppear {
            refreshTrains()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .onChange(of: selectedDirection) { _, _ in
            refreshTrains()
        }
        .refreshable {
            await scheduleService.loadSchedule()
            refreshTrains()
        }
    }

    private func refreshTrains() {
        upcomingTrains = scheduleService.getUpcomingTrains(
            for: station,
            direction: selectedDirection,
            limit: 10
        )
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

#Preview {
    NavigationStack {
        StationDetailView(station: Station.allStations[5])
            .environmentObject(ScheduleService())
    }
}
