import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var dob = Date(timeIntervalSince1970: 0)
    @State private var dobSet = false
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let dobFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private var maxDOB: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    var isValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty &&
        !password.isEmpty && password == confirmPassword && password.count >= 6 && dobSet
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        Text("Create Account")
                            .font(.displayMedium).textCase(.uppercase).tracking(0)
                            .foregroundColor(.white)
                            .padding(.top, 8)
                            .padding(.bottom, 32)

                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                MansionTextField(title: "First name", text: $firstName)
                                MansionTextField(title: "Last name", text: $lastName)
                            }
                            MansionTextField(title: "Email", text: $email, keyboardType: .emailAddress)
                            MansionTextField(title: "Phone", text: $phone, keyboardType: .phonePad)

                            // Date of birth
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
                                if !dobSet {
                                    Text("Required — must be 18+")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "#f87171"))
                                }
                            }
                            .padding(14)
                            .background(Color.surface)
                            .cornerRadius(12)

                            MansionTextField(title: "Password", text: $password, isSecure: true)
                            MansionTextField(title: "Confirm password", text: $confirmPassword, isSecure: true)
                        }
                        .padding(.horizontal, 24)

                        if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Button(action: {
                            errorMessage = nil
                            isLoading = true
                            Task {
                                do {
                                    try await AuthService.shared.register(
                                        firstName: firstName, lastName: lastName,
                                        email: email, password: password, phone: phone,
                                        dob: dobFormatter.string(from: dob)
                                    )
                                    await MainActor.run { dismiss() }
                                } catch {
                                    await MainActor.run {
                                        errorMessage = error.localizedDescription
                                        isLoading = false
                                    }
                                }
                            }
                        }) {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Create Account")
                                        .font(.titleMedium)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(isValid ? Color.brand : Color.brand.opacity(0.4))
                            .cornerRadius(14)
                        }
                        .disabled(!isValid)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.brand)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RegisterView().environmentObject(AppState())
}
