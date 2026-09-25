import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
    @MainActor
    func run(_ book: Book, _ router: Router) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3.5)
            // Scan in the aisle: a coffee with a sale tag at the usual price.
            router.staged = Demo.fakeSale(book); router.scanning = true; await wait(6)
            router.scanning = false; await wait(1.5)
            if let coffee = book.items.first(where: { $0.name == "Ground coffee" }) {
                withAnimation { router.path = [coffee.id] }; await wait(5)
                withAnimation { router.path = [] }; await wait(1.5)
            }
            router.check = Demo.stockUp(book)
            withAnimation { router.tab = .check }; await wait(5)
            router.options = Demo.compare(); router.usage = "2"; router.usageUnit = .lb
            withAnimation { router.tab = .compare }; await wait(5)
            withAnimation { router.tab = .list }; await wait(5)
            withAnimation { router.tab = .book }; await wait(1.5)
            router.settings = true; await wait(3.5)
            router.settings = false; await wait(1.5)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}
