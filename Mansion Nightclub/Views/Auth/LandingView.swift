import SwiftUI

struct LandingView: View {
    @State private var showLogin = false
    @State private var showRegister = false
    @State private var logoOpacity = 0.0
    @State private var logoOffset: CGFloat = 20
    @State private var ctaOpacity = 0.0

    var body: some View {
        ZStack {
            // Background
            Color.appBackground.ignoresSafeArea()

            // Hero image
            if let _ = UIImage(named: "HeroBG") {
                Image("HeroBG")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.5),
                                Color.black.opacity(0.92),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: [Color(hex: "#1a0a00"), Color(hex: "#0a0000")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer()

                // Logo + wordmark
                VStack(spacing: 20) {
                    Image("MansionLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)

                    VStack(spacing: 4) {
                        Text("MANSION")
                            .font(.displayLarge)
                            .tracking(6)
                            .foregroundColor(.white)
                        Text("NIGHTCLUB LIVERPOOL")
                            .font(.caption)
                            .tracking(4)
                            .foregroundColor(.textSecondary)
                    }
                }
                .opacity(logoOpacity)
                .offset(y: logoOffset)

                Spacer()

                // CTAs
                VStack(spacing: 12) {
                    Button {
                        showRegister = true
                    } label: {
                        Text("CREATE ACCOUNT")
                            .font(.label)
                            .tracking(1.5)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.brand)
                            .cornerRadius(4)
                    }

                    Button {
                        showLogin = true
                    } label: {
                        Text("LOG IN")
                            .font(.label)
                            .tracking(1.5)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
                .opacity(ctaOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                logoOpacity = 1
                logoOffset = 0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                ctaOpacity = 1
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showRegister) {
            RegisterView()
        }
    }
}

#Preview {
    LandingView()
}
