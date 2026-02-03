import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct PATCOLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PATCOActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (when long-pressed)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "tram.fill")
                            .foregroundColor(.blue)
                        Text(context.attributes.stationName)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        if context.state.showSeconds {
                            // Show seconds in red when under 1 minute
                            Text("\(context.state.secondsUntilDeparture)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            Text("sec")
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.8))
                        } else {
                            Text("\(context.state.minutesUntilDeparture)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(context.state.isArrivingSoon ? .orange : .primary)
                            Text("min")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.direction)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("to \(context.attributes.destination)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Departs at \(context.state.departureTimeString)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

            } compactLeading: {
                // Compact leading (left side of pill)
                HStack(spacing: 4) {
                    Image(systemName: "tram.fill")
                        .foregroundColor(context.state.showSeconds ? .red : .blue)
                }
            } compactTrailing: {
                // Compact trailing (right side of pill)
                if context.state.showSeconds {
                    Text("\(context.state.secondsUntilDeparture)s")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                } else {
                    Text("\(context.state.minutesUntilDeparture)m")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(context.state.isArrivingSoon ? .orange : .primary)
                }

            } minimal: {
                // Minimal (when another activity is also running)
                Image(systemName: "tram.fill")
                    .foregroundColor(context.state.showSeconds ? .red : .blue)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct LockScreenView: View {
    let context: ActivityViewContext<PATCOActivityAttributes>

    var body: some View {
        HStack {
            // Left side - Station and direction
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "tram.fill")
                        .font(.title3)
                        .foregroundColor(context.state.showSeconds ? .red : .blue)

                    Text(context.attributes.stationName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                HStack(spacing: 4) {
                    Image(systemName: context.attributes.direction == "Westbound" ? "arrow.left" : "arrow.right")
                        .font(.caption)
                    Text("to \(context.attributes.destination)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right side - Countdown
            VStack(alignment: .trailing, spacing: 2) {
                if context.state.showSeconds {
                    // Show seconds in red when under 1 minute
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(context.state.secondsUntilDeparture)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.red)

                        Text("sec")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.bottom, 4)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(context.state.minutesUntilDeparture)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(context.state.isArrivingSoon ? .orange : .primary)

                        Text("min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                }

                Text(context.state.departureTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
}

// MARK: - Previews

@available(iOS 16.1, *)
#Preview("Lock Screen - Minutes", as: .content, using: PATCOActivityAttributes(
    stationName: "Haddonfield",
    direction: "Westbound",
    destination: "15th-16th & Locust",
    tripId: "WEEKDAY_WB_42",
    scheduledDeparture: Date().addingTimeInterval(720)
)) {
    PATCOLiveActivity()
} contentStates: {
    PATCOActivityAttributes.ContentState(
        minutesUntilDeparture: 12,
        secondsUntilDeparture: 0,
        departureTimeString: "10:42 AM",
        isArrivingSoon: false,
        showSeconds: false,
        hasDeparted: false,
        lastUpdated: Date()
    )
    PATCOActivityAttributes.ContentState(
        minutesUntilDeparture: 3,
        secondsUntilDeparture: 0,
        departureTimeString: "10:33 AM",
        isArrivingSoon: true,
        showSeconds: false,
        hasDeparted: false,
        lastUpdated: Date()
    )
}

@available(iOS 16.1, *)
#Preview("Lock Screen - Seconds", as: .content, using: PATCOActivityAttributes(
    stationName: "Haddonfield",
    direction: "Westbound",
    destination: "15th-16th & Locust",
    tripId: "WEEKDAY_WB_42",
    scheduledDeparture: Date().addingTimeInterval(45)
)) {
    PATCOLiveActivity()
} contentStates: {
    PATCOActivityAttributes.ContentState(
        minutesUntilDeparture: 0,
        secondsUntilDeparture: 45,
        departureTimeString: "10:30 AM",
        isArrivingSoon: true,
        showSeconds: true,
        hasDeparted: false,
        lastUpdated: Date()
    )
    PATCOActivityAttributes.ContentState(
        minutesUntilDeparture: 0,
        secondsUntilDeparture: 10,
        departureTimeString: "10:30 AM",
        isArrivingSoon: true,
        showSeconds: true,
        hasDeparted: false,
        lastUpdated: Date()
    )
}
