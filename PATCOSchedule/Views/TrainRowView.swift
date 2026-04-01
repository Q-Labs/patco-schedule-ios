import SwiftUI

struct TrainRowView: View {
    let train: UpcomingTrain

    var minutesColor: Color {
        let minutes = train.minutesUntilDeparture
        if minutes <= 2 {
            return .red
        } else if minutes <= 5 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Minutes until departure
            VStack {
                Text("\(train.minutesUntilDeparture)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(minutesColor)
                Text("min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 60)

            // Train details
            VStack(alignment: .leading, spacing: 4) {
                Text(train.headsign)
                    .font(.headline)

                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(train.formattedDepartureTime)
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Direction indicator
            Image(systemName: train.direction == .eastbound ? "arrow.right" : "arrow.left")
                .font(.title2)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }
}

struct TrainRowCompactView: View {
    let train: UpcomingTrain

    var body: some View {
        HStack {
            Text("\(train.minutesUntilDeparture) min")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundColor(train.minutesUntilDeparture <= 5 ? .orange : .primary)

            Spacer()

            Text(train.formattedDepartureTime)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    let provider = PATCOProvider()
    let eastbound = provider.directions.first { $0.id == "eastbound" }!
    let westbound = provider.directions.first { $0.id == "westbound" }!
    List {
        TrainRowView(train: UpcomingTrain(
            departureTime: Date().addingTimeInterval(180),
            arrivalTimeString: "10:30:00",
            headsign: "Lindenwold",
            direction: eastbound,
            tripId: "123"
        ))

        TrainRowView(train: UpcomingTrain(
            departureTime: Date().addingTimeInterval(600),
            arrivalTimeString: "10:40:00",
            headsign: "15th-16th & Locust",
            direction: westbound,
            tripId: "456"
        ))
    }
}
