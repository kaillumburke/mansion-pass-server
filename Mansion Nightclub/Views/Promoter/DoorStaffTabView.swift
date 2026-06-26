import SwiftUI

// Minimal tab view for door staff — scanner + profile only
struct DoorStaffTabView: View {
    var body: some View {
        TabView {
            DoorScannerView()
                .tabItem { Label("Scanner", systemImage: "qrcode.viewfinder") }
                .tag(0)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(1)
        }
        .tint(Color.brand)
        .preferredColorScheme(.dark)
    }
}
