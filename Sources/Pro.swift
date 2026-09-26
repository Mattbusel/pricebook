import SwiftUI
import StoreKit

/// Pricebook Pro: one non-consumable. Scanning, logging, the price check, compare and the
/// shopping list are free forever, for up to `freeItems` items. Pro lifts the cap and adds
/// the price history chart and the CSV export.
///
/// Anyone who installed a build before Pro existed keeps everything. AppTransaction's
/// originalAppVersion is the build number they first installed. Only trusted in production:
/// sandbox and Xcode report made-up values, and App Review must see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.pricebook.pro"
    /// The first build that has Pro in it. Anything earlier had every feature.
    static let firstFreemiumBuild = 2
    /// Items a free book can hold. Items already over the cap are never touched.
    static let freeItems = 30

    enum Reason: String, Identifiable { case items, chart, export, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    private var updates: Task<Void, Never>?
    private let key = "pricebook.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$3.99" }

    func canAdd(_ book: Book) -> Bool { unlocked || book.items.count < Pro.freeItems }
    func ask(_ why: Reason) { if !unlocked { paywall = why } }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pricebook Pro is unlocked. Welcome back." : "No Pricebook Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall

/// A shelf edge: Pro is the item on the yellow tag, its features are what's on the shelf.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Book.self) private var book
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    /// Inside another sheet (the new item form), which takes over again once Pro unlocks.
    var embedded = false
    @State private var shown = false

    var body: some View {
        ZStack {
            Kraft()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Kicker("Pricebook Pro", color: K.green)
                        Spacer()
                        CircleButton(icon: "xmark") { dismiss() }.accessibilityLabel("Close")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline).font(.display(34, .black)).foregroundStyle(K.ink).fixedSize(horizontal: false, vertical: true)
                        Text(sub).font(.ui(15)).foregroundStyle(K.ink2).fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        feature("infinity", "Unlimited items", "The free book holds \(Pro.freeItems). Pro takes the lid off, for the whole pantry.", .items)
                        feature("chart.xyaxis.line", "Price history chart", "Six months of prices per item, a line per store, sales marked.", .chart)
                        feature("tablecells", "Spreadsheet export", "Every price you have ever logged, as a CSV.", .export)
                    }
                    .card(4)

                    HStack(alignment: .center, spacing: 14) {
                        ShelfTag(label: "Pro", price: pro.price, per: " once", style: .yellow, big: 40, foot: "no subscription")
                            .rotationEffect(.degrees(shown ? -3 : -12))
                            .scaleEffect(shown ? 1 : 0.7)
                        Text("Pays for itself the first time it catches a fake sale.")
                            .font(.display(16)).foregroundStyle(K.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)

                    if let m = pro.message {
                        Text(m).font(.ui(14, .semibold)).foregroundStyle(K.green).frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
                    }
                    BigButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") {
                        Task { await pro.buy() }
                    }
                    .disabled(pro.busy)
                    HStack(spacing: 10) {
                        Button { Task { await pro.restore() } } label: {
                            Label("Restore purchase", systemImage: "arrow.clockwise").font(.ui(14.5, .semibold)).foregroundStyle(K.ink)
                                .padding(.horizontal, 14).frame(height: 44).background(Capsule().fill(K.paper)).overlay(Capsule().strokeBorder(K.line2, lineWidth: 1))
                        }
                        .buttonStyle(Squish())
                        Spacer()
                        Button("Not now") { dismiss() }.font(.ui(14.5, .semibold)).foregroundStyle(K.ink2)
                    }
                    Text("One payment, yours for good. Family Sharing works. Every item and price you have logged stays yours, Pro or not.")
                        .font(.ui(12)).foregroundStyle(K.dim).fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.15)) { shown = true } }
        .onChange(of: pro.unlocked) { _, now in if now && !embedded { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .items: return "Your book is full."
        case .chart: return "Watch the price move."
        case .export: return "Take your prices with you."
        case .settings: return "The whole pantry."
        }
    }

    var sub: String {
        switch reason {
        case .items: return "You have logged \(book.items.count) items, the free limit is \(Pro.freeItems). Everything you have logged stays; Pro lets you add more."
        default: return "Scanning, the price check, compare and the list stay free. Pro is for the serious deal hunter."
        }
    }

    func feature(_ icon: String, _ title: String, _ body: String, _ r: Pro.Reason) -> some View {
        let hot = r == reason
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(hot ? K.ink : K.green)
                .frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 10).fill(hot ? K.tag : K.greenSoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(16, .bold)).foregroundStyle(K.ink)
                Text(body).font(.ui(13.5)).foregroundStyle(K.ink2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

/// Stands in for the chart on an item page when Pro is locked.
struct LockedChart: View {
    @Environment(Pro.self) private var pro
    let values: [Double]
    var body: some View {
        Button { pro.ask(.chart) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Kicker("Price history, six months")
                ZStack {
                    Sparkline(values: values.count >= 2 ? values : [3.2, 3.6, 3.1, 3.9, 3.4, 2.9, 3.5], color: K.green)
                        .frame(height: 110).blur(radius: 5).opacity(0.55)
                    Label("See the chart with Pro", systemImage: "lock.fill").font(.ui(15, .bold)).foregroundStyle(K.ink)
                        .padding(.horizontal, 14).frame(height: 40).background(Capsule().fill(K.tag))
                        .overlay(alignment: .top) { Capsule().fill(K.ink).frame(height: 3).padding(.horizontal, 18) }
                }
            }
            .card()
        }
        .buttonStyle(Squish())
    }
}

/// Settings section: status, the way in, and Restore.
struct ProSection: View {
    @Environment(Pro.self) private var pro
    @Environment(Book.self) private var book
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker("Pricebook Pro")
            VStack(alignment: .leading, spacing: 10) {
                if pro.unlocked {
                    Label(pro.grandfathered ? "Unlocked. Thank you for buying Pricebook early." : "Unlocked. Unlimited items, the chart and the export are yours.", systemImage: "checkmark.seal.fill")
                        .font(.ui(15, .semibold)).foregroundStyle(K.green)
                } else {
                    Text("\(book.items.count) of \(Pro.freeItems) free items used. Pro adds unlimited items, the price history chart and the spreadsheet export for \(pro.price), once.")
                        .font(.ui(14)).foregroundStyle(K.ink2).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button { pro.ask(.settings) } label: {
                            Label("See Pro", systemImage: "tag.fill").font(.ui(15, .bold)).foregroundStyle(K.ink)
                                .padding(.horizontal, 16).frame(height: 44).background(Capsule().fill(K.tag))
                        }
                        .buttonStyle(Squish())
                        Button { Task { await pro.restore() } } label: {
                            Label("Restore purchase", systemImage: "arrow.clockwise").font(.ui(15, .semibold)).foregroundStyle(K.ink)
                                .padding(.horizontal, 14).frame(height: 44).background(Capsule().fill(K.kraft)).overlay(Capsule().strokeBorder(K.line2, lineWidth: 1))
                        }
                        .buttonStyle(Squish())
                    }
                    if let m = pro.message, pro.paywall == nil { Text(m).font(.ui(13, .semibold)).foregroundStyle(K.green) }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(K.paper))
        }
    }
}
