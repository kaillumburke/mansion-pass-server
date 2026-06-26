import SwiftUI

struct GuestlistView: View {
    @EnvironmentObject var appState: AppState
    @State private var name = ""
    @State private var email = ""
    @State private var guestCount = 1
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                Text("ADD TO GUESTLIST")
                                    .font(.label).tracking(3).foregroundColor(.brand)
                            }
                            MansionTextField(title: "Full Name", text: $name)
                            MansionTextField(title: "Email Address", text: $email, keyboardType: .emailAddress)

                            // Guest count
                            HStack {
                                Text("GUESTS")
                                    .font(.label).tracking(2).foregroundColor(.textSecondary)
                                Spacer()
                                HStack(spacing: 16) {
                                    Button {
                                        if guestCount > 1 { guestCount -= 1 }
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(guestCount > 1 ? .white : .textSecondary)
                                            .frame(width: 32, height: 32)
                                            .background(Color.appBackground)
                                            .cornerRadius(8)
                                    }
                                    Text("\(guestCount)")
                                        .font(.titleMedium).foregroundColor(.white)
                                        .frame(minWidth: 20)
                                    Button {
                                        guestCount += 1
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.black)
                                            .frame(width: 32, height: 32)
                                            .background(Color.brand)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            Button { sendGuestlistPass() } label: {
                                HStack(spacing: 10) {
                                    if isSending {
                                        ProgressView().tint(.black).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text(isSending ? "SENDING..." : "SEND WALLET PASS")
                                }
                                .font(.label).tracking(1)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(name.isEmpty || email.isEmpty ? Color.brand.opacity(0.4) : Color.brand)
                                .cornerRadius(14)
                            }
                            .disabled(name.isEmpty || email.isEmpty || isSending)
                            if let err = errorMessage {
                                Text(err).font(.bodyMedium).foregroundColor(.red)
                            }
                        }
                        .padding(20)
                        .background(Color.surface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        if !appState.guestlistEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                    Text("TONIGHT'S GUESTLIST")
                                        .font(.label).tracking(3).foregroundColor(.brand)
                                    Spacer()
                                    Text("\(appState.guestlistEntries.count)")
                                        .font(.caption).foregroundColor(.black)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color.brand).cornerRadius(8)
                                }
                                .padding(.horizontal, 20)
                                ForEach(appState.guestlistEntries) { entry in
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle().fill(Color.brand.opacity(0.2)).frame(width: 40, height: 40)
                                            Text(entry.name.prefix(1).uppercased())
                                                .font(.titleMedium).foregroundColor(.brand)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.name).font(.titleMedium).foregroundColor(.white)
                                            Text(entry.email).font(.bodyMedium).foregroundColor(.textSecondary)
                                            Text("Added by \(entry.addedBy)")
                                                .font(.caption).foregroundColor(.textSecondary.opacity(0.6))
                                        }
                                        Spacer()
                                        if entry.guestCount > 1 {
                                            Text("+\(entry.guestCount - 1)")
                                                .font(.caption).tracking(1)
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 7).padding(.vertical, 3)
                                                .background(Color.brand).cornerRadius(6)
                                        }
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    }
                                    .padding(14)
                                    .background(Color.surface)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .padding(.top, 20).padding(.bottom, 40)
                }
            }
            .navigationTitle("Guestlist")
            .navigationBarTitleDisplayMode(.large)
            .alert("Pass Sent!", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A General Admission wallet pass has been emailed to \(email).")
            }
        }
    }

    private func sendGuestlistPass() {
        let guestName = name; let guestEmail = email; let count = guestCount
        let addedBy = appState.currentUser?.fullName ?? "Unknown"
        isSending = true; errorMessage = nil
        let nextEvent = appState.events.first(where: { $0.status == .published })
        Task {
            do {
                try await GuestlistService.shared.sendPass(name: guestName, email: guestEmail, event: nextEvent)
                await MainActor.run {
                    appState.guestlistEntries.append(GuestEntry(name: guestName, email: guestEmail, guestCount: count, addedBy: addedBy))
                    name = ""; email = ""; guestCount = 1; isSending = false; showSuccess = true
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isSending = false }
            }
        }
    }
}

struct GuestEntry: Identifiable {
    let id = UUID().uuidString
    let name: String
    let email: String
    let guestCount: Int
    let addedBy: String
    var checkedIn: Bool = false
}

#Preview {
    GuestlistView().environmentObject(AppState())
}
