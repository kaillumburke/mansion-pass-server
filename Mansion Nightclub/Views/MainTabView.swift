import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        switch appState.currentUser?.role {
        case .admin:     promoterTabs
        case .dj:        djTabs
        case .doorStaff: DoorStaffTabView()
        default:         customerTabs
        }
    }

    var customerTabs: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            CustomerEventsView()
                .tabItem { Label("Events", systemImage: "calendar.badge.clock") }
                .tag(1)

            TicketsView()
                .tabItem { Label("Tickets", systemImage: "ticket.fill") }
                .tag(2)

            TablesView()
                .tabItem { Label("Tables", systemImage: "wineglass.fill") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Color.brand)
        .preferredColorScheme(.dark)
    }

    var djTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            GuestlistView()
                .tabItem { Label("Guestlist", systemImage: "list.star") }
                .tag(1)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(2)
        }
        .tint(Color.brand)
        .preferredColorScheme(.dark)
    }

    var promoterTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            PromoterEventsView()
                .tabItem { Label("Events", systemImage: "calendar.badge.clock") }
                .tag(1)

            AdminGuestlistView()
                .tabItem { Label("Guestlist", systemImage: "list.star") }
                .tag(2)

            PromoterPayoutsView()
                .tabItem { Label("Revenue", systemImage: "banknote") }
                .tag(3)

            AdminMoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(4)
        }
        .tint(Color.brand)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView().environmentObject(AppState())
}
