import SwiftUI

struct SplashView: View {
    @State private var opacity = 0.0
    @State private var scale = 0.85

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Image("MansionLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) {
                    opacity = 1
                    scale = 1
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
