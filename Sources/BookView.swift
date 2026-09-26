import SwiftUI
import Charts

struct BookView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var cat: String? = nil
    @Namespace private var ns

    private var shown: [Item] {
        book.items.filter { (cat == nil || $0.category == cat) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }
    private var deals: [(Item, Entry, Verdict)] {
        let today = Day.today
        var out: [(Item, Entry, Verdict)] = []
        for it in book.items {
            guard let e = it.entries.last, e.day >= today - 16 else { continue }
            let v = book.judge(it, e).verdict
            if v == .stock || v == .good { out.append((it, e, v)) }
        }
        return out.sorted { a, b in
            let ra = a.2 == .stock ? 0 : 1, rb = b.2 == .stock ? 0 : 1
            return ra != rb ? ra < rb : a.1.day > b.1.day
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                if query.isEmpty && cat == nil && !deals.isEmpty { dealStrip }
                search
                chips
                if book.items.isEmpty { empty }
                ForEach(book.categories.filter { c in shown.contains { $0.category == c } } + extraCats, id: \.self) { c in
                    section(c, shown.filter { $0.category == c }.sorted { $0.name < $1.name })
                }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 130)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var extraCats: [String] { Array(Set(shown.map(\.category)).subtracting(book.categories)).sorted() }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pricebook").font(.display(38, .black)).foregroundStyle(K.ink)
                Text("\(book.items.count) items · \(book.priceCount.formatted()) prices · \(book.shops.count) stores")
                    .font(.ui(14, .semibold)).foregroundStyle(K.ink2)
            }
            Spacer()
            CircleButton(icon: "gearshape.fill") { router.settings = true }
        }
        .padding(.top, 6)
    }

    private var dealStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker("Good prices you just logged", color: K.green)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(deals.prefix(8)), id: \.0.id) { d in
                        Button { router.path.append(d.0.id) } label: { DealCard(item: d.0, entry: d.1, verdict: d.2) }
                            .buttonStyle(Squish())
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 6).padding(.horizontal, 2)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .bold)).foregroundStyle(K.dim)
                TextField("", text: $query, prompt: Text("Find an item").foregroundStyle(K.dim)).font(.ui(16, .medium)).foregroundStyle(K.ink)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(K.dim) }
                }
            }
            .padding(.horizontal, 14).frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.paper))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.line2, lineWidth: 1))
            Button { router.newItem = NewItemSeed(name: query) } label: {
                Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.ink))
            }
            .buttonStyle(Squish(scale: 0.9))
            .accessibilityLabel("New item")
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, "All")
                ForEach(book.categories, id: \.self) { c in chip(c, c) }
            }
            .padding(.horizontal, 1)
        }
    }
    private func chip(_ c: String?, _ label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { cat = c }
        } label: {
            Text(label).font(.ui(13.5, .semibold)).padding(.horizontal, 13).frame(height: 34)
                .foregroundStyle(cat == c ? .white : K.ink)
                .background {
                    if cat == c { Capsule().fill(K.ink).matchedGeometryEffect(id: "cat", in: ns) }
                    else { Capsule().fill(K.paper).overlay(Capsule().strokeBorder(K.line2, lineWidth: 1)) }
                }
        }
        .buttonStyle(Squish())
        .sensoryFeedback(.selection, trigger: cat)
    }

    private func section(_ c: String, _ its: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Kicker(c)
                Spacer()
                Text("\(its.count)").font(.kick(10)).foregroundStyle(K.dim)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(its.enumerated()), id: \.element.id) { i, it in
                    Button { router.path.append(it.id) } label: { ItemRow(item: it) }
                        .buttonStyle(RowPress())
                    if i < its.count - 1 { Rectangle().fill(K.line).frame(height: 1).padding(.leading, 16) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(K.paper).shadow(color: K.ink.opacity(0.06), radius: 12, x: 0, y: 6))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(K.line, lineWidth: 1))
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "barcode.viewfinder").font(.system(size: 34, weight: .semibold)).foregroundStyle(K.green)
            Text("Start with what you buy every week").font(.display(22)).foregroundStyle(K.ink)
            Rich("Next time you shop, press the green scan button and point it at a barcode. Name the item once, type the price on the shelf tag, and Pricebook remembers it. After two or three trips it starts telling you which prices are real deals.")
            BigButton(title: "Add your first item", icon: "plus") { router.newItem = NewItemSeed() }
        }
        .card(20)
    }
}

struct RowPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? K.kraft.opacity(0.7) : .clear)
    }
}

struct ItemRow: View {
    @Environment(Book.self) private var book
    let item: Item
    var body: some View {
        let s = item.stats(book.shops)
        let tr = item.trend()
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.ui(16.5, .semibold)).foregroundStyle(K.ink).lineLimit(1)
                if let b = s?.best {
                    HStack(spacing: 5) {
                        Dot(color: book.color(b), size: 8)
                        Text("Cheapest at \(book.shopName(b))").font(.ui(12.5, .medium)).foregroundStyle(K.ink2).lineLimit(1)
                    }
                } else {
                    Text("No prices yet").font(.ui(12.5, .medium)).foregroundStyle(K.dim)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Sparkline(values: item.spark(), color: (tr ?? 0) > 0.03 ? K.red : K.green).frame(width: 52, height: 22)
                if let tr, abs(tr) >= 0.03 {
                    Text((tr > 0 ? "▲ " : "▼ ") + pct(tr)).font(.ui(10, .bold)).foregroundStyle(tr > 0 ? K.red : K.green)
                } else {
                    Text("steady").font(.ui(10, .bold)).foregroundStyle(K.dim)
                }
            }
            if let s {
                let p = unitParts(s.med, item.show)
                ShelfTag(price: p.0, per: p.1, big: 19).frame(minWidth: 86, alignment: .leading)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct DealCard: View {
    @Environment(Book.self) private var book
    let item: Item
    let entry: Entry
    let verdict: Verdict
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Stamp(verdict: verdict, size: 13)
                Spacer()
                Text(Day.ago(entry.day)).font(.ui(11, .semibold)).foregroundStyle(K.dim)
            }
            Text(item.name).font(.display(19)).foregroundStyle(K.ink).lineLimit(1)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) { Dot(color: book.color(entry.shop), size: 8); Text(book.shopName(entry.shop)).font(.ui(12.5, .semibold)).foregroundStyle(K.ink2) }
                    Text(entry.sizeText).font(.ui(12, .medium)).foregroundStyle(K.dim)
                }
                Spacer()
                ShelfTag(price: cash(entry.price), style: verdict == .stock ? .green : .yellow, big: 22)
            }
        }
        .frame(width: 236)
        .card(14, radius: 18)
    }
}

// MARK: - One item

struct ItemView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var appeared = false

    var body: some View {
        if let it = book.item(itemID) {
            content(it)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func content(_ it: Item) -> some View {
        let s = it.stats(book.shops)
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    CircleButton(icon: "chevron.left") { dismiss() }
                    Spacer()
                    CircleButton(icon: "slider.horizontal.3") { router.editing = it.id }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Kicker(it.category, color: K.green)
                    Text(it.name).font(.display(34, .black)).foregroundStyle(K.ink).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        if let c = it.barcodes.first {
                            Label(prettyCode(c), systemImage: "barcode").font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(K.ink2)
                        } else {
                            Label("No barcode yet", systemImage: "barcode").font(.ui(12.5, .semibold)).foregroundStyle(K.dim)
                        }
                        Text("·").foregroundStyle(K.dim)
                        Text("\(it.entries.count) prices").font(.ui(12.5, .semibold)).foregroundStyle(K.ink2)
                    }
                }
                if let s {
                    tags(it, s)
                    if pro.unlocked { chart(it, s) } else { LockedChart(values: it.spark()) }
                    stores(it, s)
                }
                HStack(spacing: 10) {
                    BigButton(title: "Log a price", icon: "plus") { router.logging = it.id }
                    BigButton(title: "Add to list", icon: "cart.fill.badge.plus", fill: K.paper, fg: K.ink) {
                        book.addToList(it.name, item: it.id); router.say("Added to your list")
                    }
                }
                history(it)
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 130)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) { appeared = true } }
    }

    private func tags(_ it: Item, _ s: Stats) -> some View {
        HStack(spacing: 10) {
            let b = unitParts(s.lo, it.show), m = unitParts(s.med, it.show), w = unitParts(s.hi, it.show)
            ShelfTag(label: "Best", price: b.0, per: b.1, style: .green, big: 24, foot: "\(book.shopName(s.loE.shop)) · \(Day.short(s.loE.day))")
                .frame(maxWidth: .infinity, alignment: .leading)
            ShelfTag(label: "Usual", price: m.0, per: m.1, style: .yellow, big: 24, foot: "middle of \(s.n)")
                .frame(maxWidth: .infinity, alignment: .leading)
            ShelfTag(label: "Worst", price: w.0, per: w.1, style: .red, big: 24, foot: "\(book.shopName(s.hiE.shop)) · \(Day.short(s.hiE.day))")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)
    }

    private func chart(_ it: Item, _ s: Stats) -> some View {
        let shops = book.shops.filter { sh in it.entries.contains { $0.shop == sh.id } }
        let pts = it.recent().map { e in (e, e.unitPrice * it.show.factor) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Kicker("Price per \(it.show == .ct ? "item" : it.show.rawValue), six months")
                Spacer()
                HStack(spacing: 4) { Circle().strokeBorder(K.ink, lineWidth: 1.5).frame(width: 7, height: 7); Text("on sale").font(.ui(11, .semibold)).foregroundStyle(K.dim) }
            }
            Chart {
                RuleMark(y: .value("Usual", s.med * it.show.factor))
                    .foregroundStyle(K.ink.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) { Text("usual").font(.ui(10, .bold)).foregroundStyle(K.dim) }
                ForEach(pts, id: \.0.id) { p in
                    let e = p.0, v = p.1
                    LineMark(x: .value("Date", Day.date(e.day)), y: .value("Price", v), series: .value("Store", book.shopName(e.shop)))
                        .foregroundStyle(by: .value("Store", book.shopName(e.shop)))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    if e.sale {
                        PointMark(x: .value("Date", Day.date(e.day)), y: .value("Price", v))
                            .foregroundStyle(by: .value("Store", book.shopName(e.shop)))
                            .symbolSize(38)
                    }
                }
            }
            .chartForegroundStyleScale(domain: shops.map(\.name), range: shops.map { Color(hexString: $0.color) })
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(K.line2)
                    AxisValueLabel { if let d = v.as(Double.self) { Text(currencySymbol + String(format: d < 1 ? "%.2f" : "%.2f", d)).font(.ui(10, .semibold)).foregroundStyle(K.dim) } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated)).font(.ui(10, .semibold)).foregroundStyle(K.dim)
                }
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
            .frame(height: 210)
            .padding(.top, 10)
            .mask(alignment: .leading) { Rectangle().frame(maxWidth: appeared ? .infinity : 0) }
        }
        .card(16)
    }

    private func stores(_ it: Item, _ s: Stats) -> some View {
        let rows = s.per.sorted { $0.value < $1.value }
        let bestV = rows.first?.value ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            Kicker("Where it is cheapest")
            ForEach(rows, id: \.key) { r in
                let k = r.key, v = r.value
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(book.color(k)).frame(width: 4, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.shopName(k)).font(.ui(15.5, .semibold)).foregroundStyle(K.ink)
                        if let e = it.lastEntry(at: k), e.shop == k {
                            Text("\(e.sizeText) · last \(cash(e.price)) \(Day.ago(e.day))").font(.ui(12, .medium)).foregroundStyle(K.dim).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(unitText(v, it.show)).font(.price(18)).foregroundStyle(K.ink)
                    Group {
                        if k == rows.first?.key {
                            Text("BEST").font(.kick(9.5)).foregroundStyle(.white).padding(.horizontal, 7).frame(height: 20).background(Capsule().fill(K.green))
                        } else {
                            Text("+" + pct(v / bestV - 1)).font(.ui(11.5, .bold)).foregroundStyle(K.red).padding(.horizontal, 7).frame(height: 20).background(Capsule().fill(K.redSoft))
                        }
                    }
                    .frame(width: 76, alignment: .trailing)
                }
            }
            if rows.count >= 2, it.perDay > 0, let hi = rows.last {
                let save = (hi.value - bestV) * it.perDay * 365
                if save >= 5 {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "leaf.fill").foregroundStyle(K.green)
                        Rich("Buying it at **\(book.shopName(rows[0].key))** instead of \(book.shopName(hi.key)) saves about **\(cash0(save)) a year** at your pace.", size: 14)
                    }
                    .padding(12).background(RoundedRectangle(cornerRadius: 14).fill(K.greenSoft))
                }
            }
        }
        .card(16)
    }

    private func history(_ it: Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker("Every price, newest first")
            VStack(spacing: 0) {
                let es = Array(it.entries.reversed().prefix(40))
                ForEach(Array(es.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 10) {
                        Text(Day.short(e.day)).font(.ui(13, .semibold)).foregroundStyle(K.ink2).frame(width: 52, alignment: .leading)
                        Dot(color: book.color(e.shop), size: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(book.shopName(e.shop)).font(.ui(14.5, .semibold)).foregroundStyle(K.ink)
                            Text("\(e.sizeText) for \(cash(e.price))").font(.ui(12, .medium)).foregroundStyle(K.dim)
                        }
                        if e.sale {
                            Text("SALE").font(.kick(8.5)).foregroundStyle(K.red).padding(.horizontal, 5).frame(height: 17).overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(K.red, lineWidth: 1))
                        }
                        Spacer()
                        Text(unitText(e.unitPrice, it.show)).font(.price(16, .bold)).foregroundStyle(K.ink)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button(role: .destructive) { withAnimation { book.deleteEntry(e.id, from: it.id) } } label: { Label("Delete this price", systemImage: "trash") }
                    }
                    if i < es.count - 1 { Rectangle().fill(K.line).frame(height: 1).padding(.leading, 14) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(K.paper))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.line, lineWidth: 1))
            if it.entries.count > 40 { Text("Showing the latest 40. The CSV export in Settings has all \(it.entries.count).").font(.ui(12, .medium)).foregroundStyle(K.dim) }
            Text("Press and hold a price to delete it.").font(.ui(12, .medium)).foregroundStyle(K.dim)
        }
    }
}
