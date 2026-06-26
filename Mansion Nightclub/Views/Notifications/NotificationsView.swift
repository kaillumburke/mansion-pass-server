import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if appState.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.displayLarge).textCase(.uppercase).tracking(0)
                            .foregroundColor(.textSecondary)
                        Text("No notifications")
                            .font(.titleLarge).textCase(.uppercase).tracking(0)
                            .foregroundColor(.white)
                    }
                } else {
                    List {
                        ForEach(appState.notifications.sorted(by: { $0.sentAt > $1.sentAt })) { notification in
                            NotificationRowView(notification: notification)
                                .listRowBackground(Color.appBackground)
                                .listRowSeparatorTint(Color.divider)
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                .onTapGesture {
                                    appState.markNotificationRead(id: notification.id)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if appState.notifications.contains(where: { !$0.isRead }) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark all read") {
                            appState.markAllNotificationsRead()
                        }
                        .font(.bodyMedium)
                        .foregroundColor(.brand)
                    }
                }
            }
        }
    }
}

struct NotificationRowView: View {
    let notification: AppNotification

    private var timeString: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: notification.sentAt, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(notification.isRead ? Color.surface : Color.brand.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: notification.isRead ? "bell" : "bell.fill")
                    .font(.titleMedium)
                    .foregroundColor(notification.isRead ? .textSecondary : .brand)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(notification.isRead ? .bodyMedium : .titleMedium)
                        .foregroundColor(notification.isRead ? .textSecondary : .white)
                    Spacer()
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Text(notification.body)
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 14)
    }
}

#Preview {
    NotificationsView().environmentObject(AppState())
}
