import SwiftUI
import AVFoundation
import Combine

// MARK: - Camera preview via UIViewController (most reliable approach)

struct QRScannerPreview: UIViewControllerRepresentable {
    let session: AVCaptureSession

    func makeUIViewController(context: Context) -> _PreviewVC {
        _PreviewVC(session: session)
    }
    func updateUIViewController(_ vc: _PreviewVC, context: Context) {}
}

final class _PreviewVC: UIViewController {
    private let session: AVCaptureSession
    private var previewLayer: AVCaptureVideoPreviewLayer?

    init(session: AVCaptureSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

// MARK: - Scanner Session Manager

final class QRScannerSession: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    @Published var isAuthorised = false
    @Published var isDenied = false

    let captureSession = AVCaptureSession()
    private var lastScanned: String?
    private var cooldownTimer: Timer?
    private let sessionQueue = DispatchQueue(label: "qr.session.queue")
    private var isConfigured = false

    override init() {
        super.init()
        // Don't start on init — call setup() from onAppear to avoid blocking app launch
    }

    func setup() {
        if isConfigured {
            // Already set up — just restart the session
            sessionQueue.async {
                guard !self.captureSession.isRunning else { return }
                self.captureSession.startRunning()
            }
            return
        }
        checkPermission()
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.setupSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.sessionQueue.async { self?.setupSession() }
                } else {
                    DispatchQueue.main.async { self?.isDenied = true }
                }
            }
        default:
            DispatchQueue.main.async { self.isDenied = true }
        }
    }

    private func setupSession() {
        captureSession.beginConfiguration()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }

        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr, .code128, .ean13]

        captureSession.commitConfiguration()
        isConfigured = true
        captureSession.startRunning()
        DispatchQueue.main.async { self.isAuthorised = true }
    }

    func stop() {
        sessionQueue.async {
            guard self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue,
              code != lastScanned else { return }
        lastScanned = code
        scannedCode = code
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.lastScanned = nil
        }
    }
}

// MARK: - Scan Result

enum ScanResult {
    case valid(FirestoreTicket)
    case alreadyUsed(FirestoreTicket)
    case invalid

    var isValid: Bool { if case .valid = self { return true }; return false }
}

// MARK: - Door Scanner View

struct DoorScannerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var scanner = QRScannerSession()

    @State private var scanResult: ScanResult?
    @State private var showResult = false
    @State private var entryCount = 0
    @State private var scanLog: [ScanLogEntry] = []
    @State private var showLog = false
    @State private var resultTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if scanner.isDenied {
                cameraPermissionDenied
            } else if scanner.isAuthorised {
                cameraView
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(Color.brand)
                    Text("Starting camera…")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .onChange(of: scanner.scannedCode) { _, code in
            guard let code else { return }
            handleScan(code)
        }
        .onAppear { scanner.setup() }
        .onDisappear { scanner.stop() }
        .sheet(isPresented: $showLog) {
            ScanLogView(entries: scanLog, entryCount: entryCount)
        }
    }

    // MARK: - Camera + overlay

    private let finderSize: CGFloat = 260

    private var cameraView: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen camera
                QRScannerPreview(session: scanner.captureSession)
                    .frame(width: geo.size.width, height: geo.size.height)

                // Dimmed overlay with clear finder hole (evenOdd fill rule)
                ScannerOverlay(finderSize: finderSize)
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()

                // Finder border
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(showResult ? .clear : Color.brand, lineWidth: 2.5)
                        .frame(width: finderSize, height: finderSize)

                    ForEach(0..<4) { i in
                        CornerAccent()
                            .rotationEffect(.degrees(Double(i) * 90))
                            .opacity(showResult ? 0 : 1)
                    }
                }

                // Full-screen result overlay
                if showResult, let result = scanResult {
                    fullScreenResult(result)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                // Instruction label just below finder
                VStack {
                    Spacer()
                        .frame(height: geo.size.height / 2 + finderSize / 2 + 16)
                    if !showResult {
                        Text("Position QR code within the frame")
                            .font(.bodyMedium)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }

                // Top bar
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DOOR SCANNER")
                                .font(.label).tracking(3)
                                .foregroundColor(.brand)
                            Text("Scan guest ticket QR codes")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Button { showLog = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12))
                                Text("\(entryCount) IN")
                                    .font(.label).tracking(1)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.brand)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    Spacer()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func fullScreenResult(_ result: ScanResult) -> some View {
        let bgColor: Color = {
            switch result {
            case .valid: return Color(red: 0.05, green: 0.45, blue: 0.15)
            case .alreadyUsed: return Color(red: 0.5, green: 0.3, blue: 0.0)
            case .invalid: return Color(red: 0.45, green: 0.05, blue: 0.05)
            }
        }()

        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 24) {
                switch result {
                case .valid(let ticket):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 90, weight: .bold))
                        .foregroundColor(.white)
                    Text(ticket.userName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(ticket.tierName.uppercased())
                        .font(.label).tracking(3)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    Text("ADMITTED")
                        .font(.label).tracking(4)
                        .foregroundColor(.white.opacity(0.6))

                case .alreadyUsed(let ticket):
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 90, weight: .bold))
                        .foregroundColor(.white)
                    Text("ALREADY SCANNED")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text(ticket.tierName.uppercased())
                        .font(.label).tracking(3)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    if let scanned = ticket.scannedAt {
                        Text("Scanned at \(scanned.formatted(date: .omitted, time: .shortened))")
                            .font(.bodyMedium)
                            .foregroundColor(.white.opacity(0.7))
                    }

                case .invalid:
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 90, weight: .bold))
                        .foregroundColor(.white)
                    Text("INVALID TICKET")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Not found in system")
                        .font(.bodyMedium)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(40)
        }
    }

    private var cameraPermissionDenied: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash")
                .font(.system(size: 56))
                .foregroundColor(.textSecondary)
            Text("Camera Access Required")
                .font(.titleMedium)
                .foregroundColor(.white)
            Text("Go to Settings → Mansion Nightclub → Camera and allow access.")
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.label).tracking(1)
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.brand)
            .cornerRadius(8)
        }
    }

    // MARK: - Logic

    private func handleScan(_ code: String) {
        Task {
            do {
                let outcome = try await TicketService.shared.scanQRCode(code)
                await MainActor.run {
                    switch outcome {
                    case .valid(let ft):
                        let result = ScanResult.valid(ft)
                        scanResult = result
                        entryCount += 1
                        showResultBriefly()
                        logScan(code: code, result: result)
                    case .alreadyUsed(let ft):
                        let result = ScanResult.alreadyUsed(ft)
                        scanResult = result
                        showResultBriefly()
                        logScan(code: code, result: result)
                    case .invalid:
                        scanResult = .invalid
                        showResultBriefly()
                        logScan(code: code, result: .invalid)
                    }
                }
            } catch {
                await MainActor.run {
                    scanResult = .invalid
                    showResultBriefly()
                    logScan(code: code, result: .invalid)
                }
            }
        }
    }

    private func showResultBriefly() {
        withAnimation { showResult = true }
        resultTimer?.invalidate()
        resultTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { _ in
            withAnimation { showResult = false }
        }
    }

    private func logScan(code: String, result: ScanResult) {
        let entry = ScanLogEntry(
            id: UUID().uuidString,
            code: code,
            result: result,
            scannedAt: Date()
        )
        scanLog.insert(entry, at: 0)
    }
}

// MARK: - Overlay shape with finder hole

struct ScannerOverlay: Shape {
    let finderSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Outer rectangle (whole screen)
        path.addRect(rect)
        // Inner rounded rectangle (the hole) — evenOdd makes this transparent
        let hole = CGRect(
            x: (rect.width - finderSize) / 2,
            y: (rect.height - finderSize) / 2,
            width: finderSize,
            height: finderSize
        )
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: 16, height: 16))
        return path
    }
}

// MARK: - Corner accent shape

struct CornerAccent: View {
    var body: some View {
        GeometryReader { geo in
            let s: CGFloat = 22
            Path { path in
                path.move(to: CGPoint(x: 0, y: s))
                path.addLine(to: .zero)
                path.addLine(to: CGPoint(x: s, y: 0))
            }
            .stroke(Color.brand, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: 260, height: 260)
    }
}

// MARK: - Scan Log

struct ScanLogEntry: Identifiable {
    let id: String
    let code: String
    let result: ScanResult
    let scannedAt: Date
}

struct ScanLogView: View {
    let entries: [ScanLogEntry]
    let entryCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stats bar
                    HStack(spacing: 0) {
                        statCell(value: "\(entryCount)", label: "ADMITTED")
                        Divider().frame(height: 40).background(Color.divider)
                        statCell(value: "\(entries.filter { if case .alreadyUsed = $0.result { return true }; return false }.count)", label: "DUPLICATES")
                        Divider().frame(height: 40).background(Color.divider)
                        statCell(value: "\(entries.filter { if case .invalid = $0.result { return true }; return false }.count)", label: "INVALID")
                    }
                    .padding(.vertical, 16)
                    .background(Color.surface)

                    Divider().background(Color.divider)

                    if entries.isEmpty {
                        Spacer()
                        Text("No scans yet")
                            .font(.bodyMedium).foregroundColor(.textSecondary)
                        Spacer()
                    } else {
                        List {
                            ForEach(entries) { entry in
                                ScanLogRow(entry: entry)
                                    .listRowBackground(Color.surface)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.appBackground)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Scan Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.brand)
                }
            }
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.displayMedium).textCase(.uppercase).tracking(0)
                .foregroundColor(.white)
            Text(label)
                .font(.caption).tracking(1.5)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ScanLogRow: View {
    let entry: ScanLogEntry

    var icon: String {
        switch entry.result {
        case .valid: return "checkmark.circle.fill"
        case .alreadyUsed: return "arrow.triangle.2.circlepath.circle.fill"
        case .invalid: return "xmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch entry.result {
        case .valid: return .green
        case .alreadyUsed: return .orange
        case .invalid: return .red
        }
    }

    var label: String {
        switch entry.result {
        case .valid(let t): return "\(t.tierName) — \(t.userName)"
        case .alreadyUsed(let t): return "\(t.tierName) — duplicate"
        case .invalid: return "Unknown QR code"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.bodyMedium)
                    .foregroundColor(.white)
                Text(entry.code)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(entry.scannedAt, style: .time)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, 12)
    }
}
