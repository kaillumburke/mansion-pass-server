import SwiftUI

struct AdminNotificationsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCompose = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Config warning banner
                        if !OneSignalConfig.isConfigured {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("OneSignal not configured")
                                        .font(.titleMedium).foregroundColor(.white)
                                    Text("Add your App ID and REST API Key in OneSignalConfig.swift to send real push notifications.")
                                        .font(.caption).foregroundColor(.textSecondary)
                                }
                            }
                            .padding(14)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        }

                        // Stats row
                        if !appState.sentNotifications.isEmpty {
                            HStack(spacing: 12) {
                                StatCard(
                                    label: "Sent",
                                    value: "\(appState.sentNotifications.count)",
                                    icon: "paperplane.fill",
                                    color: .brand
                                )
                                StatCard(
                                    label: "Total Reached",
                                    value: "\(appState.sentNotifications.reduce(0) { $0 + $1.recipientCount })",
                                    icon: "person.2.fill",
                                    color: .green
                                )
                            }
                        }

                        // Sent history
                        if appState.sentNotifications.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 44))
                                    .foregroundColor(.textSecondary)
                                Text("No notifications sent yet")
                                    .font(.titleMedium).foregroundColor(.textSecondary)
                                Text("Tap the compose button to send your first push notification.")
                                    .font(.bodyMedium).foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionHeader("SENT NOTIFICATIONS")
                                VStack(spacing: 10) {
                                    ForEach(appState.sentNotifications) { notif in
                                        SentNotificationRow(notif: notif, events: appState.events)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Push Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCompose = true
                    } label: {
                        Label("Compose", systemImage: "square.and.pencil")
                            .foregroundColor(.brand)
                    }
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeNotificationView()
        }
    }

    func sectionHeader(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.brand).frame(width: 3, height: 14)
            Text(text).font(.label).tracking(3).foregroundColor(.brand)
        }
    }
}

// MARK: - Compose Sheet

struct ComposeNotificationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var message = ""
    @State private var audience: NotificationAudience = .everyone
    @State private var linkToEvent = false
    @State private var selectedEventId: String? = nil
    @State private var isSending = false
    @State private var errorMessage: String? = nil
    @State private var showSuccess = false
    @State private var successCount = 0

    var publishedEvents: [AppEvent] {
        appState.events.filter { $0.status == .published }.sorted { $0.date < $1.date }
    }

    var canSend: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSending
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Preview card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                Text("PREVIEW").font(.label).tracking(3).foregroundColor(.brand)
                            }

                            HStack(alignment: .top, spacing: 12) {
                                Image("MansionLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .background(Color.black)
                                    .cornerRadius(10)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("Mansion")
                                            .font(.titleMedium).foregroundColor(.white)
                                        Spacer()
                                        Text("now")
                                            .font(.caption).foregroundColor(.textSecondary)
                                    }
                                    Text(title.isEmpty ? "Notification title" : title)
                                        .font(.bodyMedium)
                                        .foregroundColor(title.isEmpty ? .textSecondary : .white)
                                    Text(message.isEmpty ? "Notification message..." : message)
                                        .font(.caption).foregroundColor(.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(14)
                            .background(Color(hex: "#1c1c1e"))
                            .cornerRadius(14)
                        }

                        // Compose fields
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                Text("MESSAGE").font(.label).tracking(3).foregroundColor(.brand)
                            }

                            composeField("Title", text: $title, limit: 65)
                            composeField("Message", text: $message, limit: 178, multiline: true)
                        }

                        // Audience
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                Text("AUDIENCE").font(.label).tracking(3).foregroundColor(.brand)
                            }

                            VStack(spacing: 0) {
                                ForEach(NotificationAudience.allCases, id: \.self) { option in
                                    Button {
                                        audience = option
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(option.rawValue)
                                                    .font(.titleMedium)
                                                    .foregroundColor(.white)
                                                Text(audienceDescription(option))
                                                    .font(.caption).foregroundColor(.textSecondary)
                                            }
                                            Spacer()
                                            if audience == option {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.brand)
                                            } else {
                                                Circle()
                                                    .stroke(Color.divider, lineWidth: 1.5)
                                                    .frame(width: 22, height: 22)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 14)
                                    }

                                    if option != NotificationAudience.allCases.last {
                                        Divider().background(Color.divider)
                                    }
                                }
                            }
                            .background(Color.surface)
                            .cornerRadius(14)
                        }

                        // Link to event
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                Text("LINK TO EVENT").font(.label).tracking(3).foregroundColor(.brand)
                            }

                            VStack(spacing: 0) {
                                Toggle(isOn: $linkToEvent) {
                                    Text("Deep-link notification to an event")
                                        .font(.bodyMedium).foregroundColor(.white)
                                }
                                .tint(.brand)
                                .padding(.horizontal, 16).padding(.vertical, 14)

                                if linkToEvent && !publishedEvents.isEmpty {
                                    Divider().background(Color.divider)
                                    ForEach(publishedEvents) { event in
                                        Button {
                                            selectedEventId = event.id
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(event.name)
                                                        .font(.titleMedium).foregroundColor(.white)
                                                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                                        .font(.caption).foregroundColor(.textSecondary)
                                                }
                                                Spacer()
                                                if selectedEventId == event.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.brand)
                                                }
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 12)
                                        }
                                        if event.id != publishedEvents.last?.id {
                                            Divider().background(Color.divider)
                                        }
                                    }
                                }
                            }
                            .background(Color.surface)
                            .cornerRadius(14)
                        }

                        // Error
                        if let err = errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text(err).font(.bodyMedium).foregroundColor(.red)
                            }
                            .padding(14)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }

                        // Send button
                        Button(action: send) {
                            ZStack {
                                if isSending {
                                    ProgressView().tint(.white)
                                } else {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Send Push Notification")
                                    }
                                    .font(.titleMedium).foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(canSend ? Color.brand : Color.surface)
                            .cornerRadius(14)
                        }
                        .disabled(!canSend)
                        .padding(.bottom, 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Compose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.brand)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Notification Sent", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Delivered to \(successCount) device\(successCount == 1 ? "" : "s").")
        }
    }

    func send() {
        errorMessage = nil
        isSending = true
        let eventId = linkToEvent ? selectedEventId : nil

        Task {
            do {
                try await appState.broadcastNotification(
                    title: title.trimmingCharacters(in: .whitespaces),
                    body: message.trimmingCharacters(in: .whitespaces),
                    audience: audience,
                    eventId: eventId
                )
                await MainActor.run {
                    successCount = appState.sentNotifications.first?.recipientCount ?? 0
                    isSending = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSending = false
                }
            }
        }
    }

    func audienceDescription(_ a: NotificationAudience) -> String {
        switch a {
        case .everyone:      return "All subscribed users"
        case .ticketHolders: return "Users with a ticket to any upcoming event"
        case .vipOnly:       return "Users holding VIP tier tickets"
        }
    }

    @ViewBuilder
    func composeField(_ label: String, text: Binding<String>, limit: Int, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).foregroundColor(.textSecondary)
                Spacer()
                Text("\(text.wrappedValue.count)/\(limit)")
                    .font(.caption)
                    .foregroundColor(text.wrappedValue.count > limit ? .red : .textSecondary)
            }
            if multiline {
                TextEditor(text: text)
                    .font(.bodyLarge).foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 80)
                    .background(Color.surface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 1))
            } else {
                TextField(label, text: text)
                    .font(.bodyLarge).foregroundColor(.white)
                    .padding(14)
                    .background(Color.surface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 1))
            }
        }
    }
}

// MARK: - Sent Notification Row

struct SentNotificationRow: View {
    let notif: SentNotification
    let events: [AppEvent]

    var linkedEvent: AppEvent? {
        guard let id = notif.eventId else { return nil }
        return events.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(notif.title)
                        .font(.titleMedium).foregroundColor(.white)
                    Text(notif.body)
                        .font(.bodyMedium).foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(notif.recipientCount)")
                        .font(.titleMedium).foregroundColor(.brand)
                    Text("reached")
                        .font(.caption).foregroundColor(.textSecondary)
                }
            }

            HStack(spacing: 10) {
                Label(notif.audience.rawValue, systemImage: "person.2")
                    .font(.caption).foregroundColor(.textSecondary)

                if let event = linkedEvent {
                    Label(event.name, systemImage: "link")
                        .font(.caption).foregroundColor(.brand)
                        .lineLimit(1)
                }

                Spacer()

                Text(notif.sentAt, style: .relative)
                    .font(.caption).foregroundColor(.textSecondary)
            }
        }
        .padding(14)
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brand.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.titleLarge).foregroundColor(.white)
                Text(label).font(.caption).foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.surface)
        .cornerRadius(12)
    }
}
