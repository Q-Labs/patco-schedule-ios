import SwiftUI

struct ContentView: View {
    @StateObject private var scheduleService = ScheduleService()
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
                    selectedStation = Station.allStations.first { $0.id == savedStationId }
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

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "tram.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("PATCO Schedule")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Get real-time train schedules for the PATCO Speedline between South Jersey and Philadelphia")
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
                if scheduleService.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

struct AllStationsView: View {
    @EnvironmentObject var scheduleService: ScheduleService

    var body: some View {
        NavigationStack {
            List {
                Section("New Jersey") {
                    ForEach(Station.allStations.filter { $0.order <= 8 }) { station in
                        NavigationLink(destination: StationDetailView(station: station)) {
                            StationQuickView(station: station)
                        }
                    }
                }

                Section("Philadelphia") {
                    ForEach(Station.allStations.filter { $0.order > 8 }) { station in
                        NavigationLink(destination: StationDetailView(station: station)) {
                            StationQuickView(station: station)
                        }
                    }
                }
            }
            .navigationTitle("All Stations")
        }
    }
}

struct StationQuickView: View {
    let station: Station
    @EnvironmentObject var scheduleService: ScheduleService

    var nextWestbound: UpcomingTrain? {
        scheduleService.getNextTrain(for: station, direction: .westbound)
    }

    var nextEastbound: UpcomingTrain? {
        scheduleService.getNextTrain(for: station, direction: .eastbound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(station.displayName)
                .font(.headline)

            HStack(spacing: 16) {
                // To Philly
                if station.order < 12 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.caption)
                            .foregroundColor(.purple)
                        if let train = nextWestbound {
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

                // To NJ
                if station.order > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.green)
                        if let train = nextEastbound {
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
        .padding(.vertical, 4)
    }
}

struct StationPickerSheet: View {
    @Binding var selectedStation: Station?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredStations: [Station] {
        if searchText.isEmpty {
            return Station.allStations
        }
        return Station.allStations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("New Jersey Stations") {
                    ForEach(filteredStations.filter { $0.order <= 8 }) { station in
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

                Section("Philadelphia Stations") {
                    ForEach(filteredStations.filter { $0.order > 8 }) { station in
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
