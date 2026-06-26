import SwiftUI

struct DressCodeView: View {
    @Environment(\.dismiss) var dismiss

    let rules = [
        "No Sports Wear",
        "No Sports Trainers (Nike Dunks, Air Force One, Yeezys Are Permitted)",
        "No Flat Sandals / Flip Flops",
        "No Outdoor Wear",
        "No Hugo Boss, Stone Island, Armani Exchange",
        "No Tracksuits",
        "No Hen Party Wear",
        "No Fancy Dress",
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Hero header
                        ZStack {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#1a1200"), Color.appBackground],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 140)

                            VStack(spacing: 6) {
                                Text("DRESSCODE")
                                    .font(.displayLarge)
                                    .tracking(6)
                                    .foregroundColor(.brand)
                                Rectangle()
                                    .fill(Color.brand)
                                    .frame(width: 40, height: 1.5)
                            }
                        }
                        .padding(.bottom, 28)

                        // Intro
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Here at Mansion Nightclub we run a strict door policy. We expect our customers to dress to impress.")
                                .font(.bodyLarge)
                                .foregroundColor(.white)
                                .lineSpacing(4)

                            Text("Our dress code is smart casual so make sure you and your guests are all looking smart.")
                                .font(.bodyLarge)
                                .foregroundColor(.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                        // Rules list
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                Text("WHAT'S NOT PERMITTED")
                                    .font(.label).tracking(3).foregroundColor(.brand)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 14)

                            VStack(spacing: 0) {
                                ForEach(Array(rules.enumerated()), id: \.offset) { i, rule in
                                    HStack(spacing: 14) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color(hex: "#8B1A1A"))
                                            .font(.system(size: 16))
                                        Text(rule)
                                            .font(.bodyLarge)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                    .background(Color.surface)

                                    if i < rules.count - 1 {
                                        Divider()
                                            .background(Color.divider)
                                            .padding(.leading, 54)
                                    }
                                }
                            }
                            .cornerRadius(14)
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)

                        // Warning
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.brand)
                                .font(.system(size: 18))
                            Text("If you or your guests do not comply with our door policy, you may be refused entry.")
                                .font(.bodyMedium)
                                .foregroundColor(.textSecondary)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(Color(hex: "#1a1200"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.brand.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                        // Sign off
                        Text("We Look Forward To Seeing You Soon.")
                            .font(.titleMedium)
                            .foregroundColor(.brand)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Dress Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.brand)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    DressCodeView()
}
