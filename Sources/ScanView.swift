import SwiftUI
import VisionKit
import Vision
import AVFoundation

/// VisionKit's live barcode reader.
struct BarcodeScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .code39, .itf14])],
                                           qualityLevel: .balanced, recognizesMultipleItems: false,
                                           isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true,
                                           isGuidanceEnabled: false, isHighlightingEnabled: false)
        vc.delegate = context.coordinator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { try? vc.startScanning() }
        return vc
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
    }
    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) { vc.stopScanning() }
    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for it in addedItems {
                if case .barcode(let b) = it, let s = b.payloadStringValue, !s.isEmpty { onCode(s); return }
            }
        }
    }
}

enum ScanPhase: Equatable { case scanning, found(UUID), unknown(String) }

struct ScanView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var phase: ScanPhase = .scanning
    @State private var draft = Draft()
    @State private var code = ""
    @State private var typing = false
    @State private var typed = ""
    @State private var picking = false
    @State private var creating: NewItemSeed? = nil
    @State private var camera: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var sweep = false
    @State private var saved = 0
    @FocusState private var focus: Bool

    private var liveScanner: Bool {
        router.staged == nil && !book.demo && camera == .authorized && DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                if liveScanner && phase == .scanning {
                    BarcodeScanner { c in handle(c) }.ignoresSafeArea()
                } else {
                    Aisle().ignoresSafeArea()
                }
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .center).ignoresSafeArea().allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 42, height: 42).background(Circle().fill(.black.opacity(0.35)))
                                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(Squish(scale: 0.9))
                        Spacer()
                        Text(phase == .scanning ? "Point at a barcode" : "Scanned").font(.ui(16, .bold)).foregroundStyle(.white)
                        Spacer()
                        if saved > 0 {
                            Text("\(saved) saved").font(.ui(12.5, .bold)).foregroundStyle(K.ink).padding(.horizontal, 10).frame(height: 28).background(Capsule().fill(K.tag))
                        } else { Color.clear.frame(width: 42, height: 42) }
                    }
                    .padding(.horizontal, 18).padding(.top, 6)
                    reticle.frame(height: phase == .scanning ? g.size.height * 0.42 : g.size.height * 0.2).padding(.top, 10)
                    Spacer(minLength: 0)
                }

                VStack {
                    Spacer()
                    panel(maxHeight: phase == .scanning ? nil : g.size.height * 0.74)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.light)
        .statusBarHidden(true)
        .animation(.spring(response: 0.45, dampingFraction: 0.84), value: phase)
        .sensoryFeedback(.success, trigger: code)
        .sheet(isPresented: $picking) {
            ItemPicker { it in
                if !code.isEmpty { book.link(code: code, to: it.id) }
                open(it)
            }
            .presentationBackground(K.kraft).presentationCornerRadius(28)
        }
        .sheet(item: $creating) { seed in
            NewItemView(seed: seed) { it in open(it) }.presentationBackground(K.kraft).presentationCornerRadius(28)
        }
        .onAppear {
            if let s = router.staged, let id = s.itemID {
                code = book.item(id)?.barcodes.first ?? ""
                draft = s; phase = .found(id); router.staged = nil
            } else if camera == .notDetermined && !book.demo {
                AVCaptureDevice.requestAccess(for: .video) { ok in DispatchQueue.main.async { camera = ok ? .authorized : .denied } }
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { sweep = true }
        }
    }

    private func handle(_ raw: String) {
        guard phase == .scanning else { return }
        let c = normalizeCode(raw)
        guard !c.isEmpty else { return }
        code = c
        if let it = book.item(code: c) { open(it) } else { phase = .unknown(c) }
    }

    private func open(_ it: Item) {
        draft = Draft.start(it, book)
        phase = .found(it.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focus = true }
    }

    private func reset() {
        focus = false
        code = ""; typed = ""; typing = false
        phase = .scanning
    }

    // MARK: Reticle

    private var reticle: some View {
        GeometryReader { g in
            let w = min(g.size.width - 72, 330), h = min(g.size.height - 20, phase == .scanning ? 190 : 120)
            ZStack {
                Corners().stroke(phase == .scanning ? .white : K.tag, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .frame(width: w, height: h)
                    .shadow(color: .black.opacity(0.35), radius: 6)
                if phase == .scanning {
                    Capsule().fill(LinearGradient(colors: [K.green2.opacity(0), K.green2, K.green2.opacity(0)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: w - 30, height: 3)
                        .shadow(color: K.green2, radius: 8)
                        .offset(y: sweep ? h / 2 - 16 : -h / 2 + 16)
                } else if !code.isEmpty {
                    VStack(spacing: 10) {
                        BarsView(code: code).frame(width: w * 0.62, height: h * 0.42)
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(K.green)
                            Text(prettyCode(code)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(K.ink)
                        }
                        .padding(.horizontal, 12).frame(height: 30).background(Capsule().fill(.white))
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Bottom panel

    @ViewBuilder
    private func panel(maxHeight: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(K.line2).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 6)
            switch phase {
            case .scanning: scanningPanel
            case .found(let id): if let it = book.item(id) { foundPanel(it) }
            case .unknown(let c): unknownPanel(c)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: maxHeight)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous).fill(K.kraft)
                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: -6)
        )
        .transition(.move(edge: .bottom))
    }

    private var scanningPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if typing {
                Text("Type the numbers under the bars").font(.display(20)).foregroundStyle(K.ink)
                HStack(spacing: 10) {
                    Field(placeholder: "e.g. 0 41190 12345 6", text: $typed, keyboard: .numberPad, font: .system(size: 18, weight: .semibold, design: .monospaced))
                        .focused($focus)
                    Button { handle(typed) } label: {
                        Image(systemName: "arrow.right").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 50, height: 50).background(RoundedRectangle(cornerRadius: 14).fill(K.green))
                    }
                    .buttonStyle(Squish(scale: 0.9))
                    .disabled(typed.filter(\.isNumber).count < 6)
                }
            } else {
                Text(message).font(.display(20)).foregroundStyle(K.ink).fixedSize(horizontal: false, vertical: true)
                Text("It remembers the barcode the first time, so next time the price check is instant.").font(.ui(14)).foregroundStyle(K.ink2)
                if camera == .denied || camera == .restricted {
                    Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                        .font(.ui(14.5, .bold)).foregroundStyle(K.green)
                }
            }
            HStack(spacing: 10) {
                BigButton(title: typing ? "Use the camera" : "Type the barcode", icon: typing ? "camera.fill" : "keyboard", fill: K.paper, fg: K.ink) {
                    withAnimation(.spring(response: 0.35)) { typing.toggle() }
                    focus = typing
                }
                BigButton(title: "Pick from book", icon: "book.closed.fill", fill: K.ink) { code = ""; picking = true }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 44).padding(.top, 8)
    }

    private var message: String {
        if book.demo || router.staged != nil { return "Hold the barcode inside the frame." }
        if camera == .denied || camera == .restricted { return "Camera access is off for Pricebook, so type the barcode or pick the item instead." }
        if !DataScannerViewController.isSupported || !DataScannerViewController.isAvailable { return "This device cannot read barcodes with the camera. Type the numbers or pick the item." }
        return "Hold the barcode inside the frame."
    }

    private func foundPanel(_ it: Item) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Kicker(it.category, color: K.green)
                        Text(it.name).font(.display(28, .black)).foregroundStyle(K.ink)
                        if let s = it.stats(book.shops) {
                            Text("You usually pay \(unitText(s.med, it.show)) · \(it.entries.count) prices").font(.ui(13.5, .semibold)).foregroundStyle(K.ink2)
                        } else {
                            Text("New to your book").font(.ui(13.5, .semibold)).foregroundStyle(K.ink2)
                        }
                    }
                    Spacer()
                    Button { reset() } label: {
                        Label("Scan", systemImage: "barcode.viewfinder").font(.ui(13.5, .bold)).foregroundStyle(K.green)
                            .padding(.horizontal, 12).frame(height: 34).background(Capsule().fill(K.greenSoft))
                    }
                    .buttonStyle(Squish())
                }
                VerdictCard(item: it, draft: draft)
                PriceForm(draft: $draft, item: it, focus: $focus)
                HStack(spacing: 10) {
                    BigButton(title: "Save price", icon: "checkmark") {
                        guard let e = draft.entry else { return }
                        book.log(e, to: it.id)
                        saved += 1
                        router.say("Saved to the book")
                        reset()
                    }
                    .opacity(draft.entry == nil ? 0.45 : 1).disabled(draft.entry == nil)
                    BigButton(title: "List", icon: "cart.fill.badge.plus", fill: K.paper, fg: K.ink) {
                        book.addToList(it.name, item: it.id); router.say("Added to your list")
                    }
                    .frame(width: 104)
                }
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 44)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func unknownPanel(_ c: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Kicker("New barcode", color: K.green)
            Text("First time you have scanned this").font(.display(24, .black)).foregroundStyle(K.ink)
            Text("Tell Pricebook what it is once. After that this barcode opens the item straight away.").font(.ui(14.5)).foregroundStyle(K.ink2)
            BigButton(title: "Add a new item", icon: "plus") { creating = NewItemSeed(code: c) }
            BigButton(title: "It is already in my book", icon: "link", fill: K.paper, fg: K.ink) { picking = true }
            Button("Scan something else") { reset() }.font(.ui(14.5, .bold)).foregroundStyle(K.green).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 44)
    }
}

/// Four bracket corners of the scan frame.
struct Corners: Shape {
    func path(in r: CGRect) -> Path {
        let l: CGFloat = 30, c: CGFloat = 14
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY + c)); p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY)); p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c)); p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY)); p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

/// UPC-A bars drawn from the digits, for the confirmation in the frame.
struct BarsView: View {
    let code: String
    private static let L = ["0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011"]
    private var bits: String {
        let d = code.compactMap(\.wholeNumberValue)
        guard d.count == 12 else { return String(repeating: "10", count: 40) }
        var s = "101"
        for i in 0..<6 { s += Self.L[d[i]] }
        s += "01010"
        for i in 6..<12 { s += String(Self.L[d[i]].map { $0 == "0" ? Character("1") : Character("0") }) }
        return s + "101"
    }
    var body: some View {
        Canvas { ctx, size in
            let b = Array(bits), w = size.width / CGFloat(b.count)
            for (i, ch) in b.enumerated() where ch == "1" {
                ctx.fill(Path(CGRect(x: CGFloat(i) * w, y: 0, width: w + 0.3, height: size.height)), with: .color(K.ink))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white))
    }
}

/// When there is no live camera: a dim supermarket shelf, drawn.
struct Aisle: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(hex: 0x2A2F2B), Color(hex: 0x151816)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var g = SeededRNG(seed: 5)
            let colors: [Color] = [Color(hex: 0xC4572F), Color(hex: 0xE3B91C), Color(hex: 0x2F6FB0), Color(hex: 0x3E8C54), Color(hex: 0xEDE3CF), Color(hex: 0x7A4FA0), Color(hex: 0xB43E2A)]
            var y: CGFloat = 70
            while y < size.height {
                var x: CGFloat = -10
                let shelfH: CGFloat = 150
                while x < size.width {
                    let w = CGFloat(34 + g.next() * 46), h = CGFloat(60 + g.next() * 80)
                    let r = CGRect(x: x, y: y + shelfH - h, width: w, height: h)
                    let c = colors[Int(g.next() * Double(colors.count)) % colors.count]
                    ctx.fill(Path(roundedRect: r, cornerRadius: 5), with: .color(c.opacity(0.55)))
                    ctx.fill(Path(CGRect(x: r.minX + 6, y: r.minY + 12, width: w - 12, height: 8)), with: .color(.white.opacity(0.18)))
                    x += w + 4 + CGFloat(g.next() * 6)
                }
                ctx.fill(Path(CGRect(x: 0, y: y + shelfH, width: size.width, height: 14)), with: .color(Color(hex: 0xBFB6A2).opacity(0.7)))
                var tx: CGFloat = 20
                while tx < size.width {
                    ctx.fill(Path(CGRect(x: tx, y: y + shelfH + 2, width: 30, height: 10)), with: .color(K.tag.opacity(0.75)))
                    tx += 70 + CGFloat(g.next() * 50)
                }
                y += shelfH + 34
            }
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.35)))
        }
        .blur(radius: 5)
    }
}
