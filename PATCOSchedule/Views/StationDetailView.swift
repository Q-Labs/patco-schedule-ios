import SwiftUI

struct StationDetailView: View {
    let station: Station
    @EnvironmentObject var scheduleService: ScheduleService
    @State private var selectedDirection: TransitDirection?
    @State private var upcomingTrains: [UpcomingTrain] = []
    @State private var refreshTimer: Timer?

    var currentDirection: TransitDirection? {
        selectedDirection ?? scheduleService.provider.directions.first
    }

    var body: some View {
        let provider = scheduleService.provider

        VStack(spacing: 0) {
            // Direction Picker
            if let current = currentDirection {
                Picker("Direction", selection: Binding(
                    get: { current },
                    set: { selectedDirection = $0 }
                )) {
                    ForEach(provider.directions) { direction in
                        Text(direction.destination)
                            .tag(direction)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }

            if let errorMessage = scheduleService.loadState.errorMessage {
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
                        Text("Next Trains to \(currentDirection?.destination ?? "")")
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
            if selectedDirection == nil {
                selectedDirection = provider.directions.first
            }
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
        guard let direction = currentDirection else { return }
        upcomingTrains = scheduleService.getUpcomingTrains(
            for: station,
            direction: direction,
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
        StationDetailView(station: PATCOProvider().stations[5])
            .environmentObject(ScheduleService())
    }
}
