import Foundation

/// Six months of believable prices at four stores, for the screenshots and the review recording.
enum Demo {
    struct Pk { let size: Double; let unit: Unit; let pack: Int; init(_ s: Double, _ u: Unit, _ p: Int = 1) { size = s; unit = u; pack = p } }
    struct Row { let name: String; let cat: String; let show: Unit; let pp: Double; let sz: Pk; let club: Pk?; let aldi: Bool; let tgt: Bool; let use: Double; let useUnit: Unit }
    static func r(_ name: String, _ cat: String, _ show: Unit, _ pp: Double, _ sz: Pk, _ club: Pk?, _ aldi: Bool, _ tgt: Bool, _ use: Double, _ useUnit: Unit) -> Row {
        Row(name: name, cat: cat, show: show, pp: pp, sz: sz, club: club, aldi: aldi, tgt: tgt, use: use, useUnit: useUnit)
    }

    static let rows: [Row] = [
        r("Bananas", "Produce", .lb, 0.62, Pk(1, .lb), Pk(3, .lb), true, true, 6, .lb),
        r("Gala apples", "Produce", .lb, 1.79, Pk(3, .lb), Pk(5.5, .lb), true, true, 4, .lb),
        r("Strawberries", "Produce", .lb, 4.39, Pk(16, .oz), Pk(32, .oz), true, true, 2, .lb),
        r("Baby spinach", "Produce", .oz, 0.78, Pk(5, .oz), Pk(16, .oz), true, true, 15, .oz),
        r("Avocados", "Produce", .ct, 1.25, Pk(1, .ct), Pk(6, .ct), true, true, 8, .ct),
        r("Yellow onions", "Produce", .lb, 1.1, Pk(3, .lb), Pk(10, .lb), true, true, 3, .lb),
        r("Russet potatoes", "Produce", .lb, 0.92, Pk(5, .lb), Pk(15, .lb), true, true, 5, .lb),
        r("Carrots", "Produce", .lb, 0.95, Pk(2, .lb), Pk(10, .lb), true, false, 2, .lb),
        r("Large eggs", "Dairy & eggs", .dozen, 3.29, Pk(12, .ct), Pk(24, .ct), true, true, 3, .dozen),
        r("Whole milk", "Dairy & eggs", .gal, 3.89, Pk(1, .gal), Pk(2, .gal), true, true, 4, .gal),
        r("Butter", "Dairy & eggs", .lb, 4.99, Pk(1, .lb), Pk(4, .lb), true, true, 1, .lb),
        r("Shredded cheddar", "Dairy & eggs", .lb, 7.18, Pk(8, .oz), Pk(2.5, .lb), true, true, 1.5, .lb),
        r("Greek yogurt", "Dairy & eggs", .oz, 0.16, Pk(32, .oz), Pk(48, .oz), true, true, 96, .oz),
        r("Cream cheese", "Dairy & eggs", .oz, 0.36, Pk(8, .oz), nil, true, true, 16, .oz),
        r("Chicken breast", "Meat & fish", .lb, 3.99, Pk(2.5, .lb), Pk(6, .lb), true, true, 6, .lb),
        r("Ground beef 80/20", "Meat & fish", .lb, 5.49, Pk(1, .lb), Pk(5, .lb), true, true, 4, .lb),
        r("Bacon", "Meat & fish", .lb, 8.65, Pk(12, .oz), Pk(4, .lb), true, true, 1.5, .lb),
        r("Salmon fillet", "Meat & fish", .lb, 10.99, Pk(1, .lb), Pk(3, .lb), true, false, 2, .lb),
        r("Ground coffee", "Pantry", .lb, 10.6, Pk(12, .oz), Pk(48, .oz), true, true, 2, .lb),
        r("Peanut butter", "Pantry", .oz, 0.2, Pk(16, .oz), Pk(80, .oz), true, true, 20, .oz),
        r("Olive oil", "Pantry", .floz, 0.56, Pk(16.9, .floz), Pk(68, .floz), true, true, 12, .floz),
        r("Spaghetti", "Pantry", .lb, 1.49, Pk(1, .lb), Pk(8, .lb), true, true, 3, .lb),
        r("Long grain rice", "Pantry", .lb, 1.25, Pk(2, .lb), Pk(25, .lb), true, true, 4, .lb),
        r("Black beans (can)", "Pantry", .oz, 0.068, Pk(15.5, .oz), Pk(15.5, .oz, 8), true, true, 62, .oz),
        r("Cheerios", "Pantry", .oz, 0.29, Pk(18, .oz), Pk(40, .oz), false, true, 36, .oz),
        r("All-purpose flour", "Pantry", .lb, 0.72, Pk(5, .lb), Pk(25, .lb), true, true, 3, .lb),
        r("Marinara sauce", "Pantry", .oz, 0.12, Pk(24, .oz), Pk(32, .oz, 3), true, true, 48, .oz),
        r("Sandwich bread", "Pantry", .oz, 0.16, Pk(20, .oz), Pk(27, .oz, 2), true, true, 80, .oz),
        r("Flour tortillas", "Pantry", .ct, 0.36, Pk(10, .ct), Pk(30, .ct), true, true, 20, .ct),
        r("Frozen broccoli", "Frozen", .oz, 0.15, Pk(12, .oz), Pk(64, .oz), true, true, 36, .oz),
        r("Frozen pizza", "Frozen", .ct, 6.49, Pk(1, .ct), Pk(4, .ct), true, true, 4, .ct),
        r("Vanilla ice cream", "Frozen", .floz, 0.095, Pk(48, .floz), nil, true, true, 48, .floz),
        r("Sparkling water", "Drinks", .floz, 0.036, Pk(12, .floz, 12), Pk(12, .floz, 35), true, true, 400, .floz),
        r("Orange juice", "Drinks", .floz, 0.085, Pk(52, .floz), Pk(89, .floz, 2), true, true, 104, .floz),
        r("Coffee creamer", "Drinks", .floz, 0.16, Pk(32, .floz), Pk(32, .floz, 2), true, true, 48, .floz),
        r("Tortilla chips", "Snacks", .oz, 0.3, Pk(13, .oz), Pk(36, .oz), true, true, 26, .oz),
        r("Granola bars", "Snacks", .ct, 0.42, Pk(12, .ct), Pk(48, .ct), true, true, 24, .ct),
        r("Paper towels", "Household", .ct, 1.62, Pk(6, .ct), Pk(12, .ct), true, true, 4, .ct),
        r("Toilet paper", "Household", .ct, 0.56, Pk(12, .ct), Pk(30, .ct), true, true, 12, .ct),
        r("Dish soap", "Household", .floz, 0.19, Pk(19.4, .floz), Pk(32, .floz, 2), true, true, 10, .floz),
        r("Laundry detergent", "Household", .floz, 0.14, Pk(92, .floz), Pk(146, .floz, 2), true, true, 40, .floz),
        r("Trash bags", "Household", .ct, 0.3, Pk(40, .ct), Pk(200, .ct), true, true, 20, .ct),
    ]

    /// A valid-looking UPC-A with its check digit.
    static func upc(_ i: Int) -> String {
        func pad(_ n: Int) -> String { let t = String(n); return String(repeating: "0", count: max(0, 5 - t.count)) + t }
        let body = "0" + pad(41_190 + (i * 37) % 900) + pad(10_000 + (i * 713) % 89_000)
        let d = body.compactMap { $0.wholeNumberValue }
        var s = 0
        for (k, v) in d.enumerated() { s += k % 2 == 0 ? v * 3 : v }
        return body + String((10 - s % 10) % 10)
    }

    static func fill(_ b: Book) {
        var seed: UInt64 = 7
        func R() -> Double { seed = (seed * 16807) % 2_147_483_647; return Double(seed) / 2_147_483_647 }
        let shops = [Shop(id: "aldi", name: "Aldi", color: "2F6FB0"), Shop(id: "kroger", name: "Kroger", color: "C4572F"), Shop(id: "costco", name: "Costco", color: "7A4FA0"), Shop(id: "target", name: "Target", color: "1D8C7E")]
        let mult: [String: Double] = ["aldi": 0.87, "kroger": 1, "costco": 0.93, "target": 1.03]
        let end = Day.today, start = end - windowDays
        var items: [Item] = []
        for (ix, row) in rows.enumerated() {
            var it = Item(name: row.name, category: row.cat, family: row.show.family, show: row.show,
                          usage: Usage(amount: row.use, unit: row.useUnit, weekly: false), barcodes: [upc(ix)])
            var carry = ["kroger"]
            if row.aldi { carry.append("aldi") }
            if row.tgt { carry.append("target") }
            if row.club != nil { carry.append("costco") }
            let vol = row.name == "Large eggs" ? 0.14 : row.name == "Ground coffee" ? 0.06 : row.cat == "Produce" ? 0.05 : 0.025
            let drift = (R() - 0.3) * 0.08
            for s in carry {
                let pk = s == "costco" ? row.club! : row.sz
                let lean = 1 + (R() - 0.5) * 0.26
                var t = Double(start) + R() * 12
                while t < Double(end) {
                    let f = (t - Double(start)) / Double(end - start)
                    var p = row.pp * mult[s]! * lean * (1 + drift * f) * (1 + vol * sin(f * 6.3 + Double(ix))) * (1 + (R() - 0.5) * 0.05)
                    var sale = false
                    let r = R()
                    if s == "kroger" && r < 0.24 { p *= 0.7 + R() * 0.1; sale = true }
                    else if s == "target" && r < 0.1 { p *= 0.86; sale = true }
                    else if s == "target" && r < 0.17 { sale = true } // a "sale" at the usual price
                    else if s == "aldi" && r < 0.05 { p *= 0.85; sale = true }
                    let amount = pk.size * Double(pk.pack) * pk.unit.factor / row.show.factor
                    let price = max(0.39, (p * amount * 10).rounded() / 10 - 0.01)
                    it.entries.append(Entry(shop: s, day: Int(t), price: (price * 100).rounded() / 100, size: pk.size, unit: pk.unit, pack: pk.pack, sale: sale))
                    t += (s == "costco" ? 30 : 13) + R() * 16
                }
            }
            it.entries.sort { $0.day < $1.day }
            items.append(it)
        }
        b.shops = shops
        b.categories = Book.defaultCategories
        b.items = items
        b.lastShop = "kroger"
        func id(_ n: String) -> UUID? { items.first { $0.name == n }?.id }
        let wants: [(String, Int)] = [("Whole milk", 2), ("Large eggs", 2), ("Bananas", 1), ("Chicken breast", 1), ("Ground coffee", 1), ("Greek yogurt", 1), ("Baby spinach", 2), ("Sandwich bread", 1), ("Shredded cheddar", 1), ("Paper towels", 1), ("Laundry detergent", 1), ("Sparkling water", 2), ("Avocados", 4), ("Spaghetti", 2)]
        b.list = wants.enumerated().map { i, w in ListLine(itemID: id(w.0), name: w.0, qty: w.1, done: i == 3 || i == 9) }
        b.list.append(ListLine(itemID: nil, name: "Birthday candles", qty: 1))
    }

    // MARK: - Screens staged for the screenshots

    /// Coffee at Target with a sale tag at the usual price: the "Fake sale" moment.
    static func fakeSale(_ b: Book) -> Draft {
        guard let it = b.items.first(where: { $0.name == "Ground coffee" }), let last = it.lastEntry(at: "target") else { return Draft() }
        let t = it.typical(at: "target") ?? it.stats(b.shops)?.med ?? 0.6
        return Draft(itemID: it.id, shop: "target", price: String(format: "%.2f", (t * last.base * 1.01 * 100).rounded() / 100), size: num(last.size), unit: last.unit, pack: last.pack, sale: true)
    }
    /// Chicken at Kroger just under the best price logged: "Stock up".
    static func stockUp(_ b: Book) -> Draft {
        guard let it = b.items.first(where: { $0.name == "Chicken breast" }), let last = it.lastEntry(at: "kroger"), let s = it.stats(b.shops) else { return Draft() }
        return Draft(itemID: it.id, shop: "kroger", price: String(format: "%.2f", floor(s.lo * 0.99 * last.base * 100) / 100), size: num(last.size), unit: last.unit, pack: last.pack, sale: true)
    }
    static func compare() -> [Option] {
        [Option(price: "7.99", size: "12", unit: .oz),
         Option(price: "", size: "24.2", unit: .oz, deal: .multi, n: "2", total: "22", coupon: "1.50"),
         Option(price: "24.99", size: "3", unit: .lb)]
    }
}
