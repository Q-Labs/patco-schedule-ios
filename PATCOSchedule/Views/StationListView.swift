import SwiftUI

struct StationListView: View {
    @EnvironmentObject var scheduleService: ScheduleService
    @Binding var selectedStation: Station?
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
        List {
            Section {
                ForEach(filteredStations) { station in
                    StationRowView(station: station, isSelected: selectedStation?.id == station.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedStation = station
                        }
                }
            } header: {
                HStack {
                    Image(systemName: "tram.fill")
                    Text("PATCO Stations")
                }
            } footer: {
                Text("Lindenwold, NJ to Philadelphia, PA")
                    .font(.caption)
            }
        }
        .searchable(text: $searchText, prompt: "Search stations")
        .navigationTitle("Stations")
    }
}

struct StationRowView: View {
    let station: Station
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.displayName)
                    .font(.headline)

                if station.displayName != station.name {
                    Text(station.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        StationListView(selectedStation: .constant(Station.allStations[0]))
            .environmentObject(ScheduleService())
    }
}
