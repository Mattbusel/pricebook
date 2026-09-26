import SwiftUI
import Observation

@main
struct PricebookApp: App {
    @State private var book: Book
    @State private var router = Router()
    @State private var pro: Pro
    init() {
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        _book = State(initialValue: Book(demo: demo))
        // Screenshots and the review recording show Pro; the paywall shot shows it locked.
        let shot = a.firstIndex(of: "-shot").flatMap { a.indices.contains($0 + 1) ? a[$0 + 1] : nil }
        _pro = State(initialValue: demo ? Pro(forced: shot != "paywall") : Pro())
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(book).environment(router).environment(pro).preferredColorScheme(.light).tint(K.green)
                .onAppear { router.applyShotArgs(book, pro); Autopilot.shared.run(book, router) }
        }
    }
}

enum Tab: String, CaseIterable {
    case book = "Book", check = "Check", compare = "Compare", list = "List"
    var icon: String {
        switch self {
        case .book: return "book.closed.fill"
        case .check: return "tag.fill"
        case .compare: return "scalemass.fill"
        case .list: return "checklist"
        }
    }
}

@Observable
final class Router {
    var tab: Tab = .book
    var path: [UUID] = []
    var scanning = false
    var settings = false
    var newItem: NewItemSeed? = nil
    var logging: UUID? = nil
    var editing: UUID? = nil
    var check = Draft()
    var options: [Option] = [Option(), Option()]
    var usage = ""
    var usageUnit: Unit = .oz
    var usageWeekly = false
    /// Set by the screenshot and review runs to open the scanner on a known product.
    var staged: Draft? = nil
    var toast: String? = nil

    func say(_ t: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = t }
        let now = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            if self?.toast == now { withAnimation(.easeOut(duration: 0.25)) { self?.toast = nil } }
        }
    }

    @MainActor
    func applyShotArgs(_ b: Book, _ pro: Pro) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        let coffee = b.items.first { $0.name == "Ground coffee" }
        switch a[i + 1] {
        case "scan": staged = Demo.fakeSale(b); scanning = true
        case "item": if let c = coffee { path = [c.id] }
        case "deal": check = Demo.stockUp(b); tab = .check
        case "compare":
            options = Demo.compare(); usage = "2"; usageUnit = .lb; tab = .compare
        case "list": tab = .list
        case "paywall":
            if let c = coffee { path = [c.id] }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { pro.ask(.chart) }
        default: break
        }
    }
}

struct NewItemSeed: Identifiable { var id = UUID(); var name = ""; var code = "" }

struct RootView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            Kraft()
            Group {
                switch router.tab {
                case .book: BookNav()
                case .check: NavigationStack { CheckView().toolbar(.hidden, for: .navigationBar) }
                case .compare: NavigationStack { CompareView().toolbar(.hidden, for: .navigationBar) }
                case .list: NavigationStack { ListView().toolbar(.hidden, for: .navigationBar) }
                }
            }
            .transition(.opacity)
            Rail(tab: $router.tab) { router.scanning = true }
                .padding(.bottom, 4)
                .ignoresSafeArea(.keyboard)
            if let t = router.toast {
                Toast(text: t).padding(.bottom, 110).transition(.move(edge: .bottom).combined(with: .opacity)).allowsHitTesting(false)
            }
        }
        .fullScreenCover(isPresented: $router.scanning) { ScanView() }
        .sheet(isPresented: $router.settings) { SettingsView().presentationBackground(K.kraft).presentationCornerRadius(28) }
        .sheet(item: $router.newItem) { seed in NewItemView(seed: seed).presentationBackground(K.kraft).presentationCornerRadius(28) }
        .sheet(item: Binding(get: { router.logging.map(IDBox.init) }, set: { router.logging = $0?.id })) { box in
            LogPriceView(itemID: box.id).presentationBackground(K.kraft).presentationCornerRadius(28)
        }
        .sheet(item: Binding(get: { router.editing.map(IDBox.init) }, set: { router.editing = $0?.id })) { box in
            EditItemView(itemID: box.id).presentationBackground(K.kraft).presentationCornerRadius(28)
        }
        // Settings and the new item form host their own paywall; this one is for the pages underneath.
        .sheet(item: Binding(get: { otherSheet ? nil : pro.paywall }, set: { pro.paywall = $0 })) { r in
            PaywallView(reason: r).presentationBackground(K.kraft).presentationCornerRadius(28)
        }
    }

    private var otherSheet: Bool {
        router.scanning || router.settings || router.newItem != nil || router.logging != nil || router.editing != nil
    }
}

struct IDBox: Identifiable { let id: UUID }

struct BookNav: View {
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            BookView()
                .navigationDestination(for: UUID.self) { id in ItemView(itemID: id) }
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// The bottom rail: four tabs on a paper strip, and the scan button raised in the middle.
struct Rail: View {
    @Binding var tab: Tab
    var scan: () -> Void
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 0) {
            button(.book); button(.check)
            Button(action: scan) {
                ZStack {
                    Circle().fill(K.green).frame(width: 66, height: 66)
                        .overlay(Circle().strokeBorder(K.greenDeep.opacity(0.5), lineWidth: 1))
                        .shadow(color: K.green.opacity(0.45), radius: 12, x: 0, y: 6)
                    Circle().strokeBorder(K.tag, lineWidth: 3).frame(width: 56, height: 56)
                    Image(systemName: "barcode.viewfinder").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                }
                .offset(y: -14)
            }
            .buttonStyle(Squish(scale: 0.9))
            .sensoryFeedback(.impact(weight: .medium), trigger: tab)
            .frame(width: 80)
            .accessibilityLabel("Scan a barcode")
            button(.compare); button(.list)
        }
        .padding(.horizontal, 8).frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(K.paper)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(K.line2, lineWidth: 1))
                .shadow(color: K.ink.opacity(0.12), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, 14)
    }
    private func button(_ t: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { tab = t }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: t.icon).font(.system(size: 18, weight: .semibold))
                Text(t.rawValue).font(.ui(10.5, .bold))
            }
            .foregroundStyle(tab == t ? K.ink : K.dim)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background {
                if tab == t {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.tag)
                        .overlay(alignment: .top) { Rectangle().fill(K.ink).frame(height: 2.5).clipShape(RoundedRectangle(cornerRadius: 1)) .padding(.horizontal, 14) }
                        .matchedGeometryEffect(id: "tab", in: ns)
                }
            }
        }
        .buttonStyle(Squish(scale: 0.92))
    }
}
