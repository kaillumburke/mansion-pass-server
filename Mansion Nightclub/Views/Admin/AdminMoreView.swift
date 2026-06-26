import SwiftUI

struct AdminMoreView: View {

    let items: [(icon: String, label: String, color: Color, destination: AnyView)] = [
        ("person.badge.plus",  "Add Guest",  .purple, AnyView(GuestlistView())),
        ("qrcode.viewfinder",  "Scanner",    .brand,  AnyView(DoorScannerView())),
        ("bell.badge.fill",    "Notify",     .orange, AnyView(AdminNotificationsView())),
        ("ticket.fill",        "Tickets",    .brand,  AnyView(NavigationStack { AdminTicketsView() })),
        ("person.2.fill",      "Users",      .blue,   AnyView(NavigationStack { UserManagementView() })),
        ("person.fill",        "Profile",    .gray,   AnyView(ProfileView())),
    ]

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items, id: \.label) { item in
                            NavigationLink(destination: item.destination) {
                                VStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(item.color.opacity(0.15))
                                            .frame(width: 56, height: 56)
                                        Image(systemName: item.icon)
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(item.color)
                                    }
                                    Text(item.label.uppercased())
                                        .font(.label)
                                        .tracking(1.5)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(Color.surface)
                                .cornerRadius(18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(item.color.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
