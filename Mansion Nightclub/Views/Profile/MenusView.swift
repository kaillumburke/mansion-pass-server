import SwiftUI

struct MenusView: View {
    @Environment(\.dismiss) var dismiss
    @State private var tab: MenuTab = .champagne

    enum MenuTab: String, CaseIterable {
        case champagne = "Champagne"
        case spirits   = "Spirits"

        var imageName: String {
            switch self {
            case .champagne: return "ChampagneMenu"
            case .spirits:   return "SpiritsMenu"
            }
        }

        var icon: String {
            switch self {
            case .champagne: return "🍾"
            case .spirits:   return "🥃"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Sub tabs
                    HStack(spacing: 0) {
                        ForEach(MenuTab.allCases, id: \.self) { t in
                            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { tab = t } }) {
                                VStack(spacing: 4) {
                                    Text("\(t.icon) \(t.rawValue)")
                                        .font(.bodyLarge)
                                        .foregroundColor(tab == t ? .brand : .textSecondary)
                                    Rectangle()
                                        .fill(tab == t ? Color.brand : Color.clear)
                                        .frame(height: 2)
                                        .cornerRadius(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .background(Color.surface)
                    .overlay(Divider().background(Color.divider), alignment: .bottom)

                    // Zoomable image
                    ZoomableImageView(imageName: tab.imageName)
                        .transition(.opacity)
                        .id(tab)
                }
            }
            .navigationTitle("Menus")
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

struct ZoomableImageView: UIViewRepresentable {
    let imageName: String

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = UIColor(Color.appBackground)
        scrollView.delegate = context.coordinator
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.tag = 100

        scrollView.addSubview(imageView)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }
        imageView.image = UIImage(named: imageName)
        DispatchQueue.main.async {
            let size = scrollView.bounds.size
            imageView.frame = CGRect(origin: .zero, size: size)
            scrollView.contentSize = size
            scrollView.zoomScale = 1.0
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(100)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = scrollView.viewWithTag(100) else { return }
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
            imageView.center = CGPoint(
                x: scrollView.contentSize.width / 2 + offsetX,
                y: scrollView.contentSize.height / 2 + offsetY
            )
        }
    }
}

#Preview {
    MenusView()
}
