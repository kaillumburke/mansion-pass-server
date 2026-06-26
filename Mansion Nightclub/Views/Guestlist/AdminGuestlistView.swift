import SwiftUI

struct AdminGuestlistView: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""

    var filtered: [GuestEntry] {
        if search.isEmpty { return appState.guestlistEntries }
        return appState.guestlistEntries.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.email.localizedCaseInsensitiveContains(search)
        }
    }

    var checkedInCount: Int { appState.guestlistEntries.filter { $0.checkedIn }.count }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if appState.guestlistEntries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.star")
                            .font(.system(size: 48))
                            .foregroundColor(.textSecondary)
                        Text("No guests yet")
                            .font(.titleLarge).textCase(.uppercase)
                            .foregroundColor(.white)
                        Text("Guests added by DJs will appear here")
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    VStack(spacing: 0) {
                        // Search bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.textSecondary)
                            TextField("Search guests...", text: $search)
                                .foregroundColor(.white)
                                .tint(.brand)
                            if !search.isEmpty {
                                Button { search = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.surface)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 10)

                        // Stats bar
                        HStack {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                Text("VIP GUESTLIST")
                                    .font(.label).tracking(3).foregroundColor(.brand)
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                Text("\(checkedInCount)/\(appState.guestlistEntries.count)")
                                    .font(.caption).foregroundColor(.black)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.brand).cornerRadius(8)
                                Text("checked in")
                                    .font(.caption).foregroundColor(.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(filtered) { entry in
                                    GuestRowView(entry: entry) {
                                        toggleCheckIn(id: entry.id)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("VIP Guestlist")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func toggleCheckIn(id: String) {
        if let index = appState.guestlistEntries.firstIndex(where: { $0.id == id }) {
            appState.guestlistEntries[index].checkedIn.toggle()
        }
    }
}

struct GuestRowView: View {
    let entry: GuestEntry
    let onCheckIn: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.checkedIn ? Color.green.opacity(0.2) : Color.brand.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(entry.name.prefix(1).uppercased())
                    .font(.titleMedium)
                    .foregroundColor(entry.checkedIn ? .green : .brand)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.titleMedium)
                    .foregroundColor(entry.checkedIn ? .textSecondary : .white)
                    .strikethrough(entry.checkedIn, color: .textSecondary)
                Text(entry.email)
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                Text("Added by \(entry.addedBy)")
                    .font(.caption)
                    .foregroundColor(.textSecondary.opacity(0.6))
            }

            Spacer()

            if entry.guestCount > 1 {
                Text("+\(entry.guestCount - 1)")
                    .font(.caption).tracking(1)
                    .foregroundColor(.black)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.brand).cornerRadius(6)
            }

            Button(action: onCheckIn) {
                ZStack {
                    Circle()
                        .fill(entry.checkedIn ? Color.green : Color.surface)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(entry.checkedIn ? Color.green : Color.brand.opacity(0.4), lineWidth: 1.5)
                        )
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(entry.checkedIn ? .black : .textSecondary)
                }
            }
        }
        .padding(14)
        .background(Color.surface)
        .cornerRadius(12)
        .opacity(entry.checkedIn ? 0.7 : 1)
    }
}

#Preview {
    AdminGuestlistView().environmentObject(AppState())
}
