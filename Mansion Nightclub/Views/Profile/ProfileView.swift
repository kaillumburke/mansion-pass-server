import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showEditProfile = false
    @State private var showLogoutConfirm = false
    @State private var showMyTickets = false
    @State private var showDressCode = false
    @State private var showMenus = false
    @State private var showOrderHistory = false
    @State private var showHelpSheet = false

    var user: AppUser? { appState.currentUser }

    var totalSpend: String {
        let total = appState.myOrders.filter { $0.status == .completed }
            .reduce(0) { $0 + $1.totalAmountInPence }
        return "£\(String(format: "%.2f", Double(total) / 100))"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Avatar + name
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brand.opacity(0.2))
                                    .frame(width: 90, height: 90)
                                Text((user?.firstName.prefix(1) ?? "?").uppercased())
                                    .font(.displayLarge).textCase(.uppercase).tracking(0)
                                    .foregroundColor(.brand)
                            }
                            .padding(.top, 8)

                            VStack(spacing: 4) {
                                Text("\(user?.firstName ?? "") \(user?.lastName ?? "")")
                                    .font(.titleLarge).textCase(.uppercase).tracking(0)
                                    .foregroundColor(.white)
                                Text(user?.email ?? "")
                                    .font(.bodyMedium)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(.bottom, 28)

                        // Stats row
                        HStack(spacing: 0) {
                            StatCell(label: "Tickets", value: "\(appState.myTickets.count)")
                            Divider().background(Color.divider)
                            StatCell(label: "Orders", value: "\(appState.myOrders.count)")
                            Divider().background(Color.divider)
                            StatCell(label: "Spent", value: totalSpend)
                        }
                        .background(Color.surface)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                        // Drinks vouchers remaining
                        if !appState.myDrinksVouchers.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 8) {
                                    Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                    Text("DRINKS REMAINING")
                                        .font(.label).tracking(3).foregroundColor(.brand)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)

                                VStack(spacing: 8) {
                                    ForEach(appState.myDrinksVouchers) { voucher in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(voucher.packageName)
                                                    .font(.titleMedium).foregroundColor(.white)
                                                Text("\(voucher.drinksUsed) of \(voucher.totalDrinks) used")
                                                    .font(.bodyMedium).foregroundColor(.textSecondary)
                                            }
                                            Spacer()
                                            VStack(spacing: 2) {
                                                Text("\(voucher.drinksRemaining)")
                                                    .font(.displayMedium).foregroundColor(.brand)
                                                Text("left")
                                                    .font(.caption).foregroundColor(.textSecondary)
                                            }
                                        }
                                        .padding(14)
                                        .background(Color.surface)
                                        .cornerRadius(12)
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                            .padding(.bottom, 24)
                        }

                        // Settings sections
                        VStack(spacing: 20) {
                            SettingsSection(title: "Account") {
                                SettingsRow(icon: "person", label: "Edit Profile") {
                                    showEditProfile = true
                                }
                                SettingsRow(icon: "lock", label: "Change Password") {}
                                SettingsRow(icon: "bell", label: "Notification Preferences") {}
                            }

                            SettingsSection(title: "My Tickets") {
                                SettingsRow(icon: "ticket.fill", label: "My Tickets") {
                                    showMyTickets = true
                                }
                            }

                            SettingsSection(title: "Venue Info") {
                                SettingsRow(icon: "tshirt", label: "Dress Code") {
                                    showDressCode = true
                                }
                                SettingsRow(icon: "wineglass", label: "Drinks Menus") {
                                    showMenus = true
                                }
                            }

                            SettingsSection(title: "Orders") {
                                SettingsRow(icon: "bag", label: "Order History") {
                                    showOrderHistory = true
                                }
                                SettingsRow(icon: "questionmark.circle", label: "Help & Support") {
                                    showHelpSheet = true
                                }
                            }

                            SettingsSection(title: "") {
                                SettingsRow(icon: "rectangle.portrait.and.arrow.right", label: "Log Out", textColor: .red) {
                                    showLogoutConfirm = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Log Out", isPresented: $showLogoutConfirm) {
                Button("Log Out", role: .destructive) { appState.logout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
            .sheet(isPresented: $showMyTickets) {
                TicketsView().environmentObject(appState)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showDressCode) {
                DressCodeView()
            }
            .sheet(isPresented: $showMenus) {
                MenusView()
            }
            .sheet(isPresented: $showOrderHistory) {
                OrderHistoryView().environmentObject(appState)
            }
            .confirmationDialog("Help & Support", isPresented: $showHelpSheet, titleVisibility: .visible) {
                Button("WhatsApp Us") {
                    // Replace 447XXXXXXXXX with the actual number
                    if let url = URL(string: "https://wa.me/447442499401?text=Hi%20Mansion%2C%20I%20need%20help%20with%20my%20order.") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Email Us") {
                    if let url = URL(string: "mailto:info@mansion-liverpool.co.uk?subject=Support%20Request") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How would you like to contact us?")
            }
        }
    }
}

struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.titleLarge).textCase(.uppercase).tracking(0)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.caption)
                    .tracking(1)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color.surface)
            .cornerRadius(14)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    var textColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.bodyLarge)
                    .foregroundColor(.brand)
                    .frame(width: 28)
                Text(label)
                    .font(.bodyLarge)
                    .foregroundColor(textColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .background(Color.surface)
        Divider()
            .background(Color.divider)
            .padding(.leading, 58)
    }
}

struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var dob = Date(timeIntervalSince1970: 0)
    @State private var dobSet = false

    private let dobFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private var maxDOB: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        MansionTextField(title: "First name", text: $firstName)
                        MansionTextField(title: "Last name", text: $lastName)
                        MansionTextField(title: "Phone", text: $phone, keyboardType: .phonePad)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("DATE OF BIRTH")
                                .font(.caption).tracking(1)
                                .foregroundColor(.textSecondary)
                            DatePicker("", selection: $dob, in: ...maxDOB, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(Color.brand)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onChange(of: dob) { _ in dobSet = true }
                        }
                        .padding(14)
                        .background(Color.surface)
                        .cornerRadius(12)

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.brand)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            guard var user = appState.auth.currentUser else { return }
                            user.firstName = firstName
                            user.lastName = lastName
                            user.phone = phone
                            if dobSet { user.dob = dobFormatter.string(from: dob) }
                            try? await AuthService.shared.saveUserProfile(user)
                            await MainActor.run { appState.auth.currentUser = user }
                            dismiss()
                        }
                    }.foregroundColor(.brand)
                }
            }
            .onAppear {
                let user = appState.currentUser
                firstName = user?.firstName ?? ""
                lastName = user?.lastName ?? ""
                phone = user?.phone ?? ""
                if let dobStr = user?.dob, let d = dobFormatter.date(from: dobStr) {
                    dob = d; dobSet = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ProfileView().environmentObject(AppState())
}
