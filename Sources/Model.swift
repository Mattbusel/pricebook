import Foundation
import Observation

// MARK: - Units

enum Family: String, Codable, CaseIterable, Identifiable {
    case weight, liquid, count
    var id: String { rawValue }
    var units: [Unit] {
        switch self {
        case .weight: return [.oz, .lb, .g, .kg]
        case .liquid: return [.floz, .qt, .gal, .ml, .l]
        case .count: return [.ct, .dozen]
        }
    }
    var label: String {
        switch self {
        case .weight: return "By weight"
        case .liquid: return "By volume"
        case .count: return "By count"
        }
    }
}

enum Unit: String, Codable, CaseIterable, Identifiable {
    case oz, lb, g, kg, floz = "fl oz", ml, l = "L", qt, gal, ct, dozen
    var id: String { rawValue }
    /// Size of one of this unit in the family's base unit (oz, fl oz or each).
    var factor: Double {
        switch self {
        case .oz: return 1
        case .lb: return 16
        case .g: return 0.0352739619
        case .kg: return 35.2739619
        case .floz: return 1
        case .ml: return 0.0338140227
        case .l: return 33.8140227
        case .qt: return 32
        case .gal: return 128
        case .ct: return 1
        case .dozen: return 12
        }
    }
    var family: Family {
        switch self {
        case .oz, .lb, .g, .kg: return .weight
        case .floz, .ml, .l, .qt, .gal: return .liquid
        case .ct, .dozen: return .count
        }
    }
    var word: String { self == .ct ? "each" : rawValue }
    var per: String { self == .ct ? " ea" : "/" + rawValue }
}

// MARK: - Days (whole local days since 1970, fast to compare)

enum Day {
    static var today: Int {
        let t = Date().timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT())
        return Int(floor(t / 86_400))
    }
    static func date(_ d: Int) -> Date { Date(timeIntervalSince1970: Double(d) * 86_400 + 43_200) }
    private static let utc: TimeZone = TimeZone(identifier: "UTC")!
    private static func fmt(_ f: String) -> DateFormatter {
        let x = DateFormatter(); x.timeZone = utc; x.locale = Locale(identifier: "en_US"); x.dateFormat = f; return x
    }
    private static let short = fmt("MMM d")
    private static let long = fmt("MMM d, yyyy")
    private static let iso = fmt("yyyy-MM-dd")
    private static let month = fmt("MMMM yyyy")
    static func short(_ d: Int) -> String { short.string(from: date(d)) }
    static func long(_ d: Int) -> String { long.string(from: date(d)) }
    static func iso(_ d: Int) -> String { iso.string(from: date(d)) }
    static func month(_ d: Int) -> String { month.string(from: date(d)) }
    static func ago(_ d: Int) -> String {
        let n = today - d
        switch n {
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2..<14: return "\(n) days ago"
        case 14..<60: return "\(n / 7) weeks ago"
        default: return "\(n / 30) months ago"
        }
    }
}

// MARK: - Records

struct Shop: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var color: String
}

struct Entry: Codable, Identifiable, Hashable {
    var id = UUID()
    var shop: String
    var day: Int
    var price: Double
    var size: Double
    var unit: Unit
    var pack: Int = 1
    var sale = false
    var base: Double { size * Double(max(pack, 1)) * unit.factor }
    var unitPrice: Double { base > 0 ? price / base : .nan }
    var sizeText: String { (pack > 1 ? "\(pack) × " : "") + num(size) + " " + unit.word }
}

struct Usage: Codable, Hashable {
    var amount: Double
    var unit: Unit
    var weekly: Bool
}

struct Item: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var category: String
    var family: Family
    var show: Unit
    var usage: Usage? = nil
    var barcodes: [String] = []
    var entries: [Entry] = []
}

struct ListLine: Codable, Identifiable, Hashable {
    var id = UUID()
    var itemID: UUID?
    var name: String
    var qty: Int = 1
    var done = false
}

// MARK: - Formatting

let money: NumberFormatter = {
    let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = Locale.current.currency?.identifier ?? "USD"; return f
}()
func cash(_ v: Double) -> String { v.isFinite ? (money.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)) : "-" }
func cash0(_ v: Double) -> String {
    let f = money.copy() as! NumberFormatter; f.maximumFractionDigits = 0; f.minimumFractionDigits = 0
    return v.isFinite ? (f.string(from: NSNumber(value: v)) ?? "\(Int(v))") : "-"
}
var currencySymbol: String { money.currencySymbol ?? "$" }
func num(_ v: Double) -> String {
    if v == v.rounded() { return String(Int(v)) }
    return String(format: v < 10 ? "%.2g" : "%.1f", v).replacingOccurrences(of: "\\.0$", with: "", options: .regularExpression)
}
/// A unit price shown in the item's display unit: "$0.313" and "/oz".
func unitParts(_ up: Double, _ show: Unit) -> (String, String) {
    guard up.isFinite else { return ("-", "") }
    let v = up * show.factor
    let s = currencySymbol + String(format: v < 1 ? "%.3f" : "%.2f", v)
    return (s, show.per)
}
func unitText(_ up: Double, _ show: Unit) -> String { let p = unitParts(up, show); return p.0 + p.1 }
func pct(_ r: Double) -> String { "\(Int((abs(r) * 100).rounded()))%" }

func median(_ a: [Double]) -> Double {
    let s = a.filter { $0.isFinite }.sorted()
    guard !s.isEmpty else { return .nan }
    let m = s.count / 2
    return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
}
func parse(_ s: String) -> Double? {
    let t = s.replacingOccurrences(of: currencySymbol, with: "").replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
    guard let v = Double(t), v.isFinite else { return nil }
    return v
}
/// UPC-A often arrives as EAN-13 with a leading zero; store both forms the same way.
func normalizeCode(_ s: String) -> String {
    let d = s.filter(\.isNumber)
    if d.count == 13, d.hasPrefix("0") { return String(d.dropFirst()) }
    return d
}
func prettyCode(_ s: String) -> String {
    guard s.count == 12 else { return s }
    let a = Array(s)
    return "\(a[0]) \(String(a[1...5])) \(String(a[6...10])) \(a[11])"
}

// MARK: - Maths on the book

let windowDays = 183

struct Stats {
    var n: Int
    var lo: Double, loE: Entry
    var hi: Double, hiE: Entry
    var med: Double
    var per: [String: Double]
    var best: String?
    var last: Entry?
}

extension Item {
    func recent(_ today: Int = Day.today) -> [Entry] { entries.filter { $0.day >= today - windowDays } }
    func typical(at shop: String) -> Double? {
        let es = entries.filter { $0.shop == shop }
        guard !es.isEmpty else { return nil }
        let reg = es.filter { !$0.sale }
        let use = Array((reg.isEmpty ? es : reg).suffix(3))
        let m = median(use.map(\.unitPrice))
        return m.isFinite ? m : nil
    }
    func stats(_ shops: [Shop]) -> Stats? {
        let r = recent()
        let all = r.isEmpty ? entries : r
        guard let first = all.first else { return nil }
        var lo = Double.infinity, hi = -Double.infinity, loE = first, hiE = first
        for e in all {
            let u = e.unitPrice
            if u < lo { lo = u; loE = e }
            if u > hi { hi = u; hiE = e }
        }
        var per: [String: Double] = [:]
        for s in shops { if let t = typical(at: s.id) { per[s.id] = t } }
        let best = per.min { $0.value < $1.value }?.key
        return Stats(n: all.count, lo: lo, loE: loE, hi: hi, hiE: hiE, med: median(all.map(\.unitPrice)), per: per, best: best, last: entries.last)
    }
    /// The pack size you usually buy, in base units; used to price the list fairly across stores.
    var refBase: Double {
        let m = median(entries.filter { !$0.sale }.map(\.base))
        return m.isFinite ? m : (entries.last?.base ?? 1)
    }
    var saleGap: Double? {
        let s = entries.filter(\.sale).map(\.day).sorted()
        guard s.count >= 2 else { return nil }
        return Double(s.last! - s.first!) / Double(s.count - 1)
    }
    /// Usage in base units per day.
    var perDay: Double {
        guard let u = usage, u.amount > 0, u.unit.family == family else { return 0 }
        return u.amount * u.unit.factor / (u.weekly ? 7 : 30.44)
    }
    /// Six monthly medians, oldest first, for the sparkline.
    func spark(_ today: Int = Day.today) -> [Double] {
        var pts: [Double] = []
        for m in stride(from: 5, through: 0, by: -1) {
            let a = Double(today) - Double(m + 1) * 30.5, b = Double(today) - Double(m) * 30.5
            let u = entries.filter { Double($0.day) > a && Double($0.day) <= b }.map(\.unitPrice)
            if !u.isEmpty { pts.append(median(u)) }
        }
        return pts
    }
    /// Change of the last two months against three to six months ago.
    func trend(_ today: Int = Day.today) -> Double? {
        let a = entries.filter { $0.day > today - 60 }.map(\.unitPrice)
        let b = entries.filter { $0.day <= today - 90 && $0.day > today - windowDays }.map(\.unitPrice)
        guard a.count >= 2, b.count >= 2 else { return nil }
        return median(a) / median(b) - 1
    }
    func lastEntry(at shop: String?) -> Entry? {
        if let shop, let e = entries.last(where: { $0.shop == shop }) { return e }
        return entries.last
    }
}

// MARK: - Verdicts

enum Verdict: String, CaseIterable {
    case stock, good, normal, fake, high, none
    var title: String {
        switch self {
        case .stock: return "Stock up"
        case .good: return "Good price"
        case .normal: return "Normal price"
        case .fake: return "Fake sale"
        case .high: return "Pricey"
        case .none: return "Too new"
        }
    }
    var line: String {
        switch self {
        case .stock: return "The lowest you have logged for this, or close to it. Buy extra."
        case .good: return "Clearly under what you usually pay. A good time to buy."
        case .normal: return "About what you usually pay. Buy it if you need it."
        case .fake: return "The tag says sale. Your own history says this is the usual price."
        case .high: return "Higher than you usually pay. Wait if you can."
        case .none: return "Log a few more prices for this and Pricebook can start calling deals."
        }
    }
}

struct Reason: Identifiable { let id = UUID(); let icon: String; let text: String }

struct Judgement {
    var verdict: Verdict
    var up: Double
    var stats: Stats?
    var ratio: Double
    var reasons: [Reason]
}

/// A price being typed in, in the aisle or on the Check tab.
struct Draft: Equatable {
    var itemID: UUID?
    var shop: String = ""
    var price: String = ""
    var size: String = ""
    var unit: Unit = .oz
    var pack: Int = 1
    var sale = false
    var entry: Entry? {
        guard let p = parse(price), p > 0, let s = parse(size), s > 0 else { return nil }
        return Entry(shop: shop, day: Day.today, price: p, size: s, unit: unit, pack: max(1, pack), sale: sale)
    }
}

extension Book {
    func judge(_ it: Item, _ e: Entry) -> Judgement {
        let u = e.unitPrice
        let r = it.recent()
        let hist = (r.isEmpty ? it.entries : r).map(\.unitPrice)
        guard let s = it.stats(shops), hist.count >= 2 else {
            return Judgement(verdict: .none, up: u, stats: nil, ratio: 1, reasons: [Reason(icon: "sparkles", text: "That is **\(unitText(u, it.show))**. You have \(hist.count) price\(hist.count == 1 ? "" : "s") for this so far.")])
        }
        let ratio = u / s.med
        let v: Verdict
        if u <= s.lo * 1.02 { v = .stock }
        else if ratio <= 0.9 { v = .good }
        else if e.sale && ratio >= 0.97 { v = .fake }
        else if ratio <= 1.06 { v = .normal }
        else { v = .high }
        var out: [Reason] = []
        let rel = ratio < 0.995 ? "**\(pct(ratio - 1)) below**" : ratio > 1.005 ? "**\(pct(ratio - 1)) above**" : "right on"
        out.append(Reason(icon: "equal.circle.fill", text: "That works out to **\(unitText(u, it.show))**. You usually pay **\(unitText(s.med, it.show))**, so this is \(rel) your usual."))
        out.append(Reason(icon: "arrow.down.circle.fill", text: "Your best is **\(unitText(s.lo, it.show))** at \(shopName(s.loE.shop)) on \(Day.short(s.loE.day))\(s.loE.sale ? ", on sale" : "")."))
        if let t = s.per[e.shop] {
            if let b = s.best, b != e.shop, let bt = s.per[b] {
                out.append(Reason(icon: "storefront.fill", text: "At \(shopName(e.shop)) you normally pay \(unitText(t, it.show)). **\(shopName(b))** is usually cheaper at **\(unitText(bt, it.show))**."))
            } else {
                out.append(Reason(icon: "storefront.fill", text: "\(shopName(e.shop)) is the cheapest store you shop for this."))
            }
        }
        if v == .fake {
            out.append(Reason(icon: "exclamationmark.triangle.fill", text: "It has a sale tag, but it is \(ratio > 1.005 ? "more than" : "about") what you normally pay. The \"was\" price on the tag is not one you have seen."))
        }
        if v == .stock || v == .good {
            let weeks = it.saleGap.map { Int((min($0, 120) / 7).rounded()) } ?? 8
            if it.perDay > 0 {
                let packs = max(1, Int(ceil(it.perDay * Double(weeks * 7) / e.base)))
                out.append(Reason(icon: "cart.fill.badge.plus", text: "It goes on sale about every **\(weeks) weeks**. At your pace that is **\(packs) \(packs == 1 ? "pack" : "packs")** to last until the next one."))
            } else {
                out.append(Reason(icon: "cart.fill.badge.plus", text: "It goes on sale about every \(weeks) weeks. Add how much you use and Pricebook will say how many to buy."))
            }
        }
        if v == .high {
            if let b = s.best, b != e.shop { out.append(Reason(icon: "arrow.turn.up.right", text: "Unless you need it today, **\(shopName(b))** usually has it for less.")) }
            else { out.append(Reason(icon: "arrow.turn.up.right", text: "Prices this high usually come back down. Buy the smallest size for now.")) }
        }
        return Judgement(verdict: v, up: u, stats: s, ratio: ratio, reasons: out)
    }
}

// MARK: - Compare

enum Deal: String, CaseIterable, Codable {
    case none = "Regular", multi = "N for $", bogo = "Buy 1 get 1", percent = "% off"
}

struct Option: Identifiable, Equatable {
    var id = UUID()
    var price = ""
    var size = ""
    var unit: Unit = .oz
    var pack = 1
    var deal: Deal = .none
    var n = "2"
    var total = ""
    var percent = ""
    var coupon = ""
    /// Price of one pack after the deal and the coupon.
    var each: Double? {
        var p: Double
        switch deal {
        case .multi:
            guard let n = parse(n), n >= 1, let t = parse(total) else { return nil }
            p = t / n
        case .bogo:
            guard let x = parse(price) else { return nil }
            p = x / 2
        case .percent:
            guard let x = parse(price) else { return nil }
            p = x * (1 - min(max(parse(percent) ?? 0, 0), 100) / 100)
        case .none:
            guard let x = parse(price) else { return nil }
            p = x
        }
        if let c = parse(coupon), c > 0 { p = max(0, p - c) }
        return p > 0 ? p : nil
    }
    var base: Double? {
        guard let s = parse(size), s > 0 else { return nil }
        return s * Double(max(1, pack)) * unit.factor
    }
    var unitPrice: Double? {
        guard let e = each, let b = base else { return nil }
        return e / b
    }
}

// MARK: - The shopping trip

struct TripLine: Identifiable { var line: ListLine; var cost: Double?; var id: UUID { line.id } }
struct TripStop: Identifiable { var shop: Shop?; var lines: [TripLine]; var total: Double; var id: String { shop?.id ?? "-" } }
struct Single: Identifiable { var shop: Shop; var total: Double; var missing: Int; var id: String { shop.id } }
struct Trip {
    var stops: [TripStop]
    var total: Double
    var singles: [Single]
    var saving: Double?
    var cheapestSingle: Shop?
}

extension Book {
    func plan() -> Trip {
        let open = shops.filter { !skip.contains($0.id) }
        var buckets: [String: [TripLine]] = [:]
        var loose: [TripLine] = []
        var split = 0.0
        for l in list {
            guard let id = l.itemID, let it = item(id) else { loose.append(TripLine(line: l, cost: nil)); continue }
            var best: (String, Double)? = nil
            for s in open { if let t = it.typical(at: s.id), best == nil || t < best!.1 { best = (s.id, t) } }
            if let b = best {
                let sid = b.0, c = b.1 * it.refBase * Double(l.qty)
                buckets[sid, default: []].append(TripLine(line: l, cost: c))
                if !l.done { split += c }
            } else { loose.append(TripLine(line: l, cost: nil)) }
        }
        let sorter: (TripLine, TripLine) -> Bool = { a, b in a.line.done == b.line.done ? a.line.name < b.line.name : !a.line.done }
        var stops: [TripStop] = open.compactMap { s in
            guard let ls = buckets[s.id], !ls.isEmpty else { return nil }
            return TripStop(shop: s, lines: ls.sorted(by: sorter), total: ls.filter { !$0.line.done }.compactMap(\.cost).reduce(0, +))
        }
        stops.sort { $0.lines.count > $1.lines.count }
        if !loose.isEmpty { stops.append(TripStop(shop: nil, lines: loose.sorted(by: sorter), total: 0)) }
        var singles: [Single] = []
        for s in open {
            var t = 0.0, miss = 0
            for l in list where !l.done {
                guard let id = l.itemID, let it = item(id) else { continue }
                if let up = it.typical(at: s.id) { t += up * it.refBase * Double(l.qty) } else { miss += 1 }
            }
            singles.append(Single(shop: s, total: t, missing: miss))
        }
        let full = singles.filter { $0.missing == 0 }.min { $0.total < $1.total }
        let saving = full.map { $0.total - split }
        return Trip(stops: stops, total: split, singles: singles, saving: saving, cheapestSingle: full?.shop)
    }
}

// MARK: - The book itself

@Observable
final class Book {
    var shops: [Shop] = []
    var categories: [String] = []
    var items: [Item] = []
    var list: [ListLine] = []
    var skip: Set<String> = []
    var lastShop: String? = nil
    let demo: Bool

    static let palette = ["2F6FB0", "C4572F", "7A4FA0", "1D8C7E", "B58A1B", "A33C6B", "4F7A2A", "5A5F6B"]
    static let defaultCategories = ["Produce", "Dairy & eggs", "Meat & fish", "Pantry", "Frozen", "Drinks", "Snacks", "Household"]

    init(demo: Bool) {
        self.demo = demo
        if demo { Demo.fill(self) } else { load() }
    }

    struct Snapshot: Codable {
        var shops: [Shop]; var categories: [String]; var items: [Item]; var list: [ListLine]; var skip: [String]; var lastShop: String?
    }
    static var url: URL { URL.documentsDirectory.appending(path: "pricebook.json") }

    func load() {
        if let d = try? Data(contentsOf: Self.url), let s = try? JSONDecoder().decode(Snapshot.self, from: d) {
            shops = s.shops; categories = s.categories; items = s.items; list = s.list; skip = Set(s.skip); lastShop = s.lastShop
        } else {
            shops = [Shop(id: "main", name: "Main store", color: Self.palette[0]), Shop(id: "discount", name: "Discount store", color: Self.palette[1]), Shop(id: "club", name: "Warehouse club", color: Self.palette[2])]
            categories = Self.defaultCategories
        }
    }
    func save() {
        guard !demo else { return }
        let s = Snapshot(shops: shops, categories: categories, items: items, list: list, skip: Array(skip), lastShop: lastShop)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: Self.url, options: .atomic) }
    }

    func shop(_ id: String) -> Shop? { shops.first { $0.id == id } }
    func shopName(_ id: String) -> String { shop(id)?.name ?? "another store" }
    func item(_ id: UUID) -> Item? { items.first { $0.id == id } }
    func item(code: String) -> Item? { let c = normalizeCode(code); return items.first { $0.barcodes.contains(c) } }
    var priceCount: Int { items.reduce(0) { $0 + $1.entries.count } }

    func update(_ it: Item) {
        if let i = items.firstIndex(where: { $0.id == it.id }) { items[i] = it } else { items.append(it) }
        save()
    }
    func log(_ e: Entry, to id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].entries.append(e)
        items[i].entries.sort { $0.day < $1.day }
        lastShop = e.shop
        save()
    }
    func deleteEntry(_ eid: UUID, from id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].entries.removeAll { $0.id == eid }
        save()
    }
    func deleteItem(_ id: UUID) {
        items.removeAll { $0.id == id }
        list.removeAll { $0.itemID == id }
        save()
    }
    func link(code: String, to id: UUID) {
        let c = normalizeCode(code)
        guard !c.isEmpty, let i = items.firstIndex(where: { $0.id == id }) else { return }
        for j in items.indices { items[j].barcodes.removeAll { $0 == c } }
        items[i].barcodes.append(c)
        save()
    }
    func addToList(_ name: String, item id: UUID?, qty: Int = 1) {
        if let id, let i = list.firstIndex(where: { $0.itemID == id && !$0.done }) { list[i].qty += qty }
        else { list.insert(ListLine(itemID: id, name: name, qty: qty), at: 0) }
        save()
    }
    func addShop(_ name: String) {
        let used = Set(shops.map(\.color))
        let c = Self.palette.first { !used.contains($0) } ?? Self.palette[shops.count % Self.palette.count]
        shops.append(Shop(id: UUID().uuidString, name: name, color: c))
        save()
    }
    func removeShop(_ id: String) {
        guard shops.count > 1 else { return }
        shops.removeAll { $0.id == id }
        for i in items.indices { items[i].entries.removeAll { $0.shop == id } }
        skip.remove(id)
        save()
    }
    func eraseAll() {
        items = []; list = []; skip = []; lastShop = nil
        try? FileManager.default.removeItem(at: Self.url)
        load(); save()
    }
    func csv() -> URL {
        var rows = ["item,category,store,date,price,size,unit,pack,sale,unit_price,per"]
        func q(_ s: String) -> String { s.contains(",") || s.contains("\"") ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s }
        for it in items.sorted(by: { $0.name < $1.name }) {
            for e in it.entries {
                rows.append([q(it.name), q(it.category), q(shopName(e.shop)), Day.iso(e.day), String(format: "%.2f", e.price), num(e.size), e.unit.rawValue, String(e.pack), e.sale ? "yes" : "no", String(format: "%.4f", e.unitPrice * it.show.factor), it.show.rawValue].joined(separator: ","))
            }
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "Pricebook prices.csv")
        try? rows.joined(separator: "\n").data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }
}
