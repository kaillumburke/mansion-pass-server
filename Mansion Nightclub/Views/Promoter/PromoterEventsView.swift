import SwiftUI
import FirebaseFirestore

struct PromoterEventsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateEvent = false
    @State private var editingEvent: AppEvent? = nil
    @State private var showPastEvents = false

    private let db = Firestore.firestore()

    var upcomingEvents: [AppEvent] {
        appState.events.filter { $0.date >= Date() }.sorted { $0.date < $1.date }
    }

    var pastEvents: [AppEvent] {
        appState.events.filter { $0.date < Date() }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if upcomingEvents.isEmpty && pastEvents.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.textSecondary)
                                Text("No events yet")
                                    .font(.titleMedium)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        }

                        ForEach(upcomingEvents) { event in
                            NavigationLink(destination: EventSalesDetailView(event: event)) {
                                EventSalesRowView(event: event)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                eventContextMenu(event)
                            }
                        }

                        if !pastEvents.isEmpty {
                            Button {
                                withAnimation { showPastEvents.toggle() }
                            } label: {
                                HStack {
                                    Image(systemName: showPastEvents ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                    Text("Previous Events (\(pastEvents.count))")
                                        .font(.label)
                                        .tracking(1)
                                }
                                .foregroundColor(.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                            }

                            if showPastEvents {
                                ForEach(pastEvents) { event in
                                    NavigationLink(destination: EventSalesDetailView(event: event)) {
                                        EventSalesRowView(event: event)
                                            .opacity(0.6)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        eventContextMenu(event)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.brand)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateEvent) {
            EventSetupView()
        }
        .sheet(item: $editingEvent) { event in
            EventSetupView(editingEvent: event)
        }
    }

    @ViewBuilder
    private func eventContextMenu(_ event: AppEvent) -> some View {
        Button {
            editingEvent = event
        } label: {
            Label("Edit Event", systemImage: "pencil")
        }

        if event.status == .published {
            Button {
                toggleStatus(event, to: .draft)
            } label: {
                Label("Unpublish", systemImage: "eye.slash")
            }
        } else {
            Button {
                toggleStatus(event, to: .published)
            } label: {
                Label("Publish", systemImage: "checkmark.circle")
            }
        }
    }

    private func toggleStatus(_ event: AppEvent, to newStatus: EventStatus) {
        Task {
            try? await db.collection("events").document(event.id)
                .updateData(["status": newStatus.rawValue.uppercased()])
        }
    }
}

// MARK: - Sales Row

struct EventSalesRowView: View {
    let event: AppEvent

    var soldPercent: Double {
        event.capacity > 0 ? Double(event.ticketsSold) / Double(event.capacity) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.titleLarge).textCase(.uppercase).tracking(0)
                        .foregroundColor(.white)
                    Text(event.date, style: .date)
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                StatusBadge(status: event.status)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(event.ticketsSold) sold")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(event.capacity - event.ticketsSold) remaining")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.divider).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Color(hex: "#e8cb8e"), Color.brand], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * soldPercent, height: 4)
                    }
                }
                .frame(height: 4)
            }

            HStack(spacing: 0) {
                RevenueCell(label: "Gross", value: event.grossRevenue)
                Divider().background(Color.divider)
                RevenueCell(label: "Promoter", value: event.promoterRevenue)
                Divider().background(Color.divider)
                RevenueCell(label: "Our Fees", value: event.netBookingFees)
            }
            .background(Color.surfaceElevated)
            .cornerRadius(10)
        }
        .padding(16)
        .background(Color.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brand.opacity(0.12), lineWidth: 1))
    }
}

struct RevenueCell: View {
    let label: String
    let value: Int

    var formatted: String { "£\(String(format: "%.2f", Double(value) / 100))" }

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
            Text(formatted)
                .font(.titleMedium)
                .foregroundColor(.brand)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

struct StatusBadge: View {
    let status: EventStatus
    var body: some View {
        Text(status == .published ? "LIVE" : status.rawValue)
            .font(.caption)
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
    var color: Color {
        switch status {
        case .published: return .green
        case .draft: return .orange
        case .cancelled: return .red
        case .completed: return .textSecondary
        }
    }
}
