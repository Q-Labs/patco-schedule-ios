import SwiftUI

struct ContentView: View {
    @StateObject private var scheduleService = ScheduleService(provider: PATCOProvider())
    @State private var selectedStation: Station?
    @State private var showingStationPicker = false
    @AppStorage("savedStationId") private var savedStationId: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if let station = selectedStation {
                    MainScheduleView(station: station, onChangeStation: {
                        showingStationPicker = true
                    })
                } else {
                    WelcomeView(onSelectStation: {
                        showingStationPicker = true
                    })
                }
            }
            .environmentObject(scheduleService)
            .sheet(isPresented: $showingStationPicker) {
                StationPickerSheet(selectedStation: $selectedStation)
                    .environmentObject(scheduleService)
            }
            .task {
                await scheduleService.loadSchedule()

                // Restore saved station
                if !savedStationId.isEmpty {
                    selectedStation = scheduleService.provider.stations.first { $0.id == savedStationId }
                }
            }
            .onChange(of: selectedStation) { _, newStation in
                if let station = newStation {
                    savedStationId = station.id
                }
            }
        }
    }
}

struct WelcomeView: View {
    let onSelectStation: () -> Void
    @EnvironmentObject var scheduleService: ScheduleService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "tram.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text(scheduleService.provider.displayName)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(scheduleService.provider.tagline)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button(action: onSelectStation) {
                Label("Select Your Station", systemImage: "mappin.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

struct MainScheduleView: View {
    let station: Station
    let onChangeStation: () -> Void
    @EnvironmentObject var scheduleService: ScheduleService
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if !scheduleService.hasScheduleData {
                // No data yet - show appropriate state
                switch scheduleService.loadState {
                case .loading:
                    ScheduleLoadingView(retryInfo: nil)
                case .retrying(let attempt, let maxAttempts):
                    ScheduleLoadingView(retryInfo: (attempt, maxAttempts))
                case .waitingForNetwork:
                    NetworkWaitingView()
                case .error(let message):
                    FullScreenErrorView(message: message) {
                        Task {
                            await scheduleService.loadSchedule()
                        }
                    }
                default:
                    ScheduleLoadingView(retryInfo: nil)
                }
            } else {
                TabView(selection: $selectedTab) {
                    // Quick View Tab
                    NextTrainView(station: station)
                        .tabItem {
                            Label("Next Train", systemImage: "clock.fill")
                        }
                        .tag(0)

                    // Full Schedule Tab
                    StationDetailView(station: station)
                        .tabItem {
                            Label("Schedule", systemImage: "list.bullet")
                        }
                        .tag(1)

                    // All Stations Tab
                    AllStationsView()
                        .tabItem {
                            Label("All Stations", systemImage: "map")
                        }
                        .tag(2)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onChangeStation) {
                    HStack {
                        Image(systemName: "mappin.circle")
                        Text(station.displayName)
                            .fontWeight(.semibold)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if scheduleService.isLoading && scheduleService.hasScheduleData {
                    // Only show small spinner when refreshing (already have data)
                    ProgressView()
                }
            }
        }
    }
}

/// Full-screen loading view shown when app is loading initial data
struct ScheduleLoadingView: View {
    let retryInfo: (attempt: Int, maxAttempts: Int)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated train icon
            Image(systemName: "tram.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolEffect(.pulse, options: .repeating)

            if let retry = retryInfo {
                Text("Retrying...")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Attempt \(retry.attempt) of \(retry.maxAttempts)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Loading Schedule")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Fetching the latest train times...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 8)

            Spacer()

            // Subtle footer
            Text("This may take a moment on first launch")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
        }
    }
}

/// View shown when waiting for network connection
struct NetworkWaitingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("No Internet Connection")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Waiting for network to load schedule data.\nThe app will automatically retry when connected.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ProgressView()
                .scaleEffect(1.0)
                .padding(.top, 8)

            Spacer()

            // Help text
            VStack(spacing: 8) {
                Text("Tips:")
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("• Check your WiFi or cellular connection\n• Move to an area with better signal\n• Disable airplane mode if enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
        }
    }
}

/// Full-screen error view when no data is available
struct FullScreenErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Unable to Load Schedule")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Help text
            VStack(spacing: 8) {
                Text("Troubleshooting:")
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("• Check your internet connection\n• Try again in a few moments\n• Restart the app if the issue persists")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 40)
        }
    }
}

struct AllStationsView: View {
    @EnvironmentObject var scheduleService: ScheduleService

    var body: some View {
        let provider = scheduleService.provider
        List {
            ForEach(provider.stationGroups) { group in
                let groupStations = provider.stations.filter { group.stationIds.contains($0.id) }
                Section(group.name) {
                    ForEach(groupStations) { station in
                        NavigationLink(destination: StationDetailView(station: station)) {
                            StationQuickView(station: station)
                        }
                    }
                }
            }
        }
        .navigationTitle("All Stations")
    }
}

struct StationQuickView: View {
    let station: Station
    @EnvironmentObject var scheduleService: ScheduleService

    var body: some View {
        let provider = scheduleService.provider
        VStack(alignment: .leading, spacing: 8) {
            Text(station.displayName)
                .font(.headline)

            HStack(spacing: 16) {
                ForEach(provider.directions) { direction in
                    if !provider.isTerminus(station: station, direction: direction) {
                        let nextTrain = scheduleService.getNextTrain(for: station, direction: direction)
                        HStack(spacing: 4) {
                            Text(direction.shortLabel)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(direction.color)
                            if let train = nextTrain {
                                Text("\(train.minutesUntilDeparture)m")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("--")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StationPickerSheet: View {
    @Binding var selectedStation: Station?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var scheduleService: ScheduleService
    @State private var searchText = ""

    func filteredStations(for group: StationGroup) -> [Station] {
        let groupStations = scheduleService.provider.stations.filter { group.stationIds.contains($0.id) }
        if searchText.isEmpty {
            return groupStations
        }
        return groupStations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        let provider = scheduleService.provider
        NavigationStack {
            List {
                ForEach(provider.stationGroups) { group in
                    let stations = filteredStations(for: group)
                    if !stations.isEmpty {
                        Section(group.name) {
                            ForEach(stations) { station in
                                Button {
                                    selectedStation = station
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(station.displayName)
                                                .foregroundColor(.primary)
                                            if station.displayName != station.name {
                                                Text(station.name)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if selectedStation?.id == station.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search stations")
            .navigationTitle("Select Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
