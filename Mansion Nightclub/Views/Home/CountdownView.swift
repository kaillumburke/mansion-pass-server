import SwiftUI
import Combine

struct CountdownView: View {
    @State private var timeRemaining: (days: Int, hours: Int, minutes: Int, seconds: Int) = (0, 0, 0, 0)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            Text("COME DANCE WITH US")
                .font(.label)
                .tracking(3)
                .foregroundColor(.brand)

            HStack(spacing: 16) {
                CountdownUnit(value: timeRemaining.days, label: "DAYS")
                divider
                CountdownUnit(value: timeRemaining.hours, label: "HRS")
                divider
                CountdownUnit(value: timeRemaining.minutes, label: "MIN")
                divider
                CountdownUnit(value: timeRemaining.seconds, label: "SEC")
            }
        }
        .onReceive(timer) { _ in
            timeRemaining = nextSaturdayCountdown()
        }
        .onAppear {
            timeRemaining = nextSaturdayCountdown()
        }
    }

    var divider: some View {
        Text(":")
            .font(.displayMedium).textCase(.uppercase).tracking(0)
            .foregroundColor(.brand.opacity(0.5))
    }

    private func nextSaturdayCountdown() -> (Int, Int, Int, Int) {
        let calendar = Calendar.current
        let now = Date()
        var components = DateComponents()
        components.weekday = 7 // Saturday
        components.hour = 22
        components.minute = 0
        components.second = 0

        guard let next = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else {
            return (0, 0, 0, 0)
        }

        let diff = Int(next.timeIntervalSince(now))
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60
        let seconds = diff % 60
        return (days, hours, minutes, seconds)
    }
}

struct CountdownUnit: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.displayMedium).textCase(.uppercase).tracking(0)
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .tracking(2)
                .foregroundColor(.textSecondary)
        }
    }
}
