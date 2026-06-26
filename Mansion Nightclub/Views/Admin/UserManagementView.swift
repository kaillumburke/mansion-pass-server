import SwiftUI

struct UserManagementView: View {
    @State private var users: [DBUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedUser: DBUser?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Color.brand)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.textSecondary)
                    Text(error)
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") { Task { await loadUsers() } }
                        .foregroundColor(.brand)
                }
            } else {
                userList
            }
        }
        .navigationTitle("Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadUsers() }
        .sheet(item: $selectedUser) { user in
            RoleEditorSheet(user: user) { updated in
                if let idx = users.firstIndex(where: { $0.id == updated.id }) {
                    users[idx] = updated
                }
            }
        }
    }

    private var userList: some View {
        List {
            ForEach(UserRole.allCases, id: \.self) { role in
                let roleUsers = users.filter { $0.role == role }
                if !roleUsers.isEmpty {
                    Section {
                        ForEach(roleUsers) { user in
                            UserRow(user: user)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedUser = user }
                                .listRowBackground(Color.surface)
                        }
                    } header: {
                        Text(role.displayName.uppercased())
                            .font(.label).tracking(2)
                            .foregroundColor(.brand)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await AuthService.shared.fetchAllUsers()
            await MainActor.run {
                users = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - User Row

struct UserRow: View {
    let user: DBUser

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.15))
                    .frame(width: 42, height: 42)
                Text(user.firstName.prefix(1) + user.lastName.prefix(1))
                    .font(.titleMedium)
                    .foregroundColor(.brand)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(user.fullName)
                    .font(.bodyMedium)
                    .foregroundColor(.white)
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: user.role.icon)
                    .font(.system(size: 11))
                Text(user.role.displayName)
                    .font(.caption).tracking(0.5)
            }
            .foregroundColor(.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary.opacity(0.5))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Role Editor Sheet

struct RoleEditorSheet: View {
    let user: DBUser
    let onSaved: (DBUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: UserRole
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(user: DBUser, onSaved: @escaping (DBUser) -> Void) {
        self.user = user
        self.onSaved = onSaved
        _selectedRole = State(initialValue: user.role)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // User header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.brand.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Text(user.firstName.prefix(1) + user.lastName.prefix(1))
                                .font(.displayMedium)
                                .foregroundColor(.brand)
                        }
                        Text(user.fullName)
                            .font(.titleMedium)
                            .foregroundColor(.white)
                        Text(user.email)
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.vertical, 32)

                    Divider().background(Color.divider)

                    // Role picker
                    VStack(spacing: 0) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Button {
                                selectedRole = role
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: role.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedRole == role ? .brand : .textSecondary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(role.displayName)
                                            .font(.bodyMedium)
                                            .foregroundColor(.white)
                                        Text(roleDescription(role))
                                            .font(.caption)
                                            .foregroundColor(.textSecondary)
                                    }

                                    Spacer()

                                    if selectedRole == role {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.brand)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                            }
                            Divider().background(Color.divider).padding(.leading, 68)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption).foregroundColor(.red)
                            .padding(.horizontal, 24).padding(.top, 12)
                    }

                    Spacer()

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        ZStack {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Text("SAVE CHANGES")
                                    .font(.label).tracking(1.5)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedRole != user.role ? Color.brand : Color.brand.opacity(0.4))
                        .cornerRadius(4)
                    }
                    .disabled(selectedRole == user.role || isSaving)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Edit Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.textSecondary)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        do {
            try await AuthService.shared.updateRole(userId: user.id, role: selectedRole)
            var updated = user
            updated.role = selectedRole
            await MainActor.run {
                onSaved(updated)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func roleDescription(_ role: UserRole) -> String {
        switch role {
        case .admin:     return "Full access — manage events, staff, notifications and revenue"
        case .customer:  return "Browse events, buy tickets, view their orders"
        case .doorStaff: return "Scanner only — verify tickets at the door"
        case .dj:        return "Guestlist access — add guests and send wallet passes"
        }
    }
}
