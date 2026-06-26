import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showRegister = false
    @State private var rememberMe = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.brand.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Text("M")
                                .font(.displayLarge).textCase(.uppercase).tracking(0)
                                .foregroundColor(.brand)
                        }
                        .padding(.top, 60)

                        Text("MANSION")
                            .font(.titleLarge).textCase(.uppercase).tracking(0)
                            .foregroundColor(.white)

                        Text("Sign in to your account")
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.bottom, 48)

                    // Form
                    VStack(spacing: 16) {
                        MansionTextField(title: "Email", text: $email, keyboardType: .emailAddress)
                        MansionTextField(title: "Password", text: $password, isSecure: true)

                        // Remember me
                        Button { rememberMe.toggle() } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(rememberMe ? Color.brand : Color.white.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 20, height: 20)
                                    if rememberMe {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.brand)
                                            .frame(width: 20, height: 20)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                Text("Remember me")
                                    .font(.bodyMedium)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                    }

                    Button(action: {
                        errorMessage = nil
                        isLoading = true
                        Task {
                            do {
                                try await AuthService.shared.login(email: email, password: password)
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
                                Text("Sign In")
                                    .font(.titleMedium)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.brand)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                    Button("Forgot password?") {}
                        .font(.bodyMedium)
                        .foregroundColor(.brand)
                        .padding(.top, 16)

                    Spacer().frame(height: 48)

                    HStack {
                        Text("New to Mansion?")
                            .foregroundColor(.textSecondary)
                        Button("Create account") { showRegister = true }
                            .foregroundColor(.brand)
                    }
                    .font(.bodyMedium)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }
}

#Preview {
    LoginView().environmentObject(AppState())
}
