import SwiftUI

extension Draft {
    static func start(_ it: Item, _ b: Book, shop: String? = nil) -> Draft {
        let sh = shop ?? b.lastShop.flatMap { id in b.shops.contains { $0.id == id } ? id : nil } ?? it.stats(b.shops)?.best ?? b.shops.first?.id ?? ""
        let last = it.lastEntry(at: sh)
        return Draft(itemID: it.id, shop: sh, price: "", size: last.map { num($0.size) } ?? "", unit: last?.unit ?? it.show, pack: last?.pack ?? 1, sale: false)
    }
}

// MARK: - The form you fill in from a shelf tag

struct PriceForm: View {
    @Environment(Book.self) private var book
    @Binding var draft: Draft
    let item: Item
    var focus: FocusState<Bool>.Binding
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(book.shops) { s in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                draft.shop = s.id
                                if let e = item.lastEntry(at: s.id), e.shop == s.id { draft.size = num(e.size); draft.unit = e.unit; draft.pack = e.pack }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(draft.shop == s.id ? .white : Color(hexString: s.color)).frame(width: 8, height: 8)
                                Text(s.name).font(.ui(14, .semibold))
                            }
                            .padding(.horizontal, 13).frame(height: 36)
                            .foregroundStyle(draft.shop == s.id ? .white : K.ink)
                            .background(Capsule().fill(draft.shop == s.id ? Color(hexString: s.color) : K.paper))
                            .overlay(Capsule().strokeBorder(draft.shop == s.id ? .clear : K.line2, lineWidth: 1))
                        }
                        .buttonStyle(Squish())
                    }
                }
                .padding(.horizontal, 1)
            }
            .sensoryFeedback(.selection, trigger: draft.shop)

            HStack(alignment: .top, spacing: 12) {
                // The price, typed onto a shelf tag.
                VStack(alignment: .leading, spacing: 0) {
                    Text("PRICE ON THE TAG").font(.kick(9)).tracking(0.8).foregroundStyle(K.ink.opacity(0.6))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(currencySymbol).font(.price(28, .bold)).foregroundStyle(K.ink.opacity(0.7))
                        TextField("", text: $draft.price, prompt: Text("0.00").foregroundStyle(K.ink.opacity(0.3)))
                            .font(.price(46)).foregroundStyle(K.ink)
                            .keyboardType(.decimalPad)
                            .focused(focus)
                    }
                }
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(K.tag)
                .overlay(alignment: .top) { Rectangle().fill(K.ink).frame(height: 4) }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .compositingGroup()
                .shadow(color: K.ink.opacity(0.18), radius: 0, x: 0, y: 2)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { draft.sale.toggle() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: draft.sale ? "tag.fill" : "tag").font(.system(size: 20, weight: .bold))
                        Text(draft.sale ? "Sale tag" : "No sale\ntag").font(.ui(11, .bold)).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(draft.sale ? .white : K.ink2)
                    .frame(width: 82, height: 86)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(draft.sale ? K.red : K.paper))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(draft.sale ? .clear : K.line2, lineWidth: 1))
                }
                .buttonStyle(Squish(scale: 0.92))
                .sensoryFeedback(.impact(weight: .light), trigger: draft.sale)
            }

            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    TextField("", text: $draft.size, prompt: Text("Size").foregroundStyle(K.dim))
                        .font(.ui(17, .semibold)).foregroundStyle(K.ink).keyboardType(.decimalPad).focused(focus)
                        .padding(.leading, 14)
                    Menu {
                        ForEach(item.family.units) { u in Button(u.word) { draft.unit = u } }
                    } label: {
                        HStack(spacing: 4) { Text(draft.unit.word).font(.ui(15, .bold)); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold)) }
                            .foregroundStyle(K.ink).padding(.horizontal, 12).frame(height: 36)
                            .background(Capsule().fill(K.kraft))
                    }
                    .padding(.trailing, 7)
                }
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.paper))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.line2, lineWidth: 1))

                HStack(spacing: 0) {
                    Button { if draft.pack > 1 { draft.pack -= 1 } } label: { Image(systemName: "minus").frame(width: 34, height: 50) }
                    VStack(spacing: 0) {
                        Text("×\(draft.pack)").font(.price(18)).contentTransition(.numericText())
                        Text(draft.pack == 1 ? "single" : "pack").font(.ui(9.5, .bold)).foregroundStyle(K.dim)
                    }
                    .frame(minWidth: 42)
                    Button { draft.pack += 1 } label: { Image(systemName: "plus").frame(width: 34, height: 50) }
                }
                .font(.system(size: 13, weight: .bold)).foregroundStyle(K.ink)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.paper))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.line2, lineWidth: 1))
                .animation(.spring(response: 0.3), value: draft.pack)
                .sensoryFeedback(.selection, trigger: draft.pack)
            }
        }
    }
}

// MARK: - The verdict

struct VerdictCard: View {
    @Environment(Book.self) private var book
    let item: Item
    let draft: Draft
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let e = draft.entry {
                let j = book.judge(item, e)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker("Verdict at \(book.shopName(draft.shop))")
                        Text(unitText(j.up, item.show)).font(.price(22)).foregroundStyle(K.ink).contentTransition(.numericText())
                    }
                    Spacer()
                    Stamp(verdict: j.verdict, size: compact ? 22 : 27)
                        .id(j.verdict)
                        .transition(.asymmetric(insertion: .scale(scale: 2.2).combined(with: .opacity), removal: .opacity))
                }
                Text(j.verdict.line).font(.display(17, .semibold)).foregroundStyle(K.ink).fixedSize(horizontal: false, vertical: true)
                if let s = j.stats { PriceGauge(stats: s, up: j.up, show: item.show, verdict: j.verdict) }
                if !compact {
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(j.reasons) { r in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: r.icon).font(.system(size: 15, weight: .bold)).foregroundStyle(j.verdict == .fake ? K.red : K.green).frame(width: 20)
                                Rich(r.text, size: 14.5)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "tag.fill").font(.system(size: 22)).foregroundStyle(K.tagDeep).rotationEffect(.degrees(-20))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Type the price and size").font(.display(17)).foregroundStyle(K.ink)
                        Text("Pricebook checks it against every price you have logged for \(item.name.lowercased()).").font(.ui(13.5)).foregroundStyle(K.ink2)
                    }
                }
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.58), value: draft.entry?.unitPrice ?? -1)
        .sensoryFeedback(trigger: draft.entry.map { book.judge(item, $0).verdict.rawValue } ?? "") { _, new in
            guard let v = Verdict(rawValue: new) else { return nil }
            switch v {
            case .stock, .good: return .success
            case .fake, .high: return .warning
            default: return nil
            }
        }
        .card(18, radius: 22)
    }
}

/// Where this price sits between your best and your worst.
struct PriceGauge: View {
    let stats: Stats
    let up: Double
    let show: Unit
    let verdict: Verdict
    var body: some View {
        let lo = min(stats.lo, up), hi = max(stats.hi, up)
        let span = max(hi - lo, 1e-9)
        GeometryReader { g in
            let w = g.size.width
            let X: (Double) -> CGFloat = { v in 8 + CGFloat((v - lo) / span) * (w - 16) }
            ZStack(alignment: .topLeading) {
                Capsule().fill(LinearGradient(colors: [K.green, K.green2, K.tag, K.amber, K.red], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10).offset(y: 34)
                ForEach([("best", stats.lo), ("usual", stats.med), ("worst", stats.hi)], id: \.0) { m in
                    VStack(spacing: 2) {
                        Rectangle().fill(K.ink.opacity(0.55)).frame(width: 1.5, height: 16)
                        Text(m.0).font(.ui(10, .bold)).foregroundStyle(K.dim)
                        Text(unitParts(m.1, show).0).font(.price(12, .bold)).foregroundStyle(K.ink2)
                    }
                    .fixedSize()
                    .position(x: X(m.1), y: 62)
                }
                VStack(spacing: 0) {
                    Text(unitParts(up, show).0).font(.price(13)).foregroundStyle(.white)
                        .padding(.horizontal, 7).frame(height: 22)
                        .background(Capsule().fill(verdict.color == K.ink2 ? K.ink : verdict.color))
                    Triangle().fill(verdict.color == K.ink2 ? K.ink : verdict.color).frame(width: 10, height: 6)
                }
                .fixedSize()
                .position(x: X(up), y: 17)
            }
        }
        .frame(height: 84)
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.closeSubpath() } }
}

// MARK: - Check tab

struct CheckView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @FocusState private var focus: Bool
    @State private var picking = false
    var body: some View {
        @Bindable var router = router
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Is it a deal?").font(.display(34, .black)).foregroundStyle(K.ink)
                    Text("Type what the shelf says. Pricebook checks it against everything you have paid.").font(.ui(14.5, .medium)).foregroundStyle(K.ink2)
                }
                .padding(.top, 14)
                if book.items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your book is empty").font(.display(20)).foregroundStyle(K.ink)
                        Text("Add an item and a couple of prices first. Then this page tells you whether a new price is a deal.").font(.ui(14)).foregroundStyle(K.ink2)
                        BigButton(title: "Add an item", icon: "plus") { router.newItem = NewItemSeed() }
                    }
                    .card(18)
                }
                Button { picking = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "basket.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(K.green)
                            .frame(width: 42, height: 42).background(Circle().fill(K.greenSoft))
                        VStack(alignment: .leading, spacing: 2) {
                            Kicker("Item")
                            Text(router.check.itemID.flatMap { book.item($0)?.name } ?? "Choose an item").font(.display(20)).foregroundStyle(K.ink)
                        }
                        Spacer()
                        Text("Change").font(.ui(13.5, .bold)).foregroundStyle(K.green)
                    }
                    .card(12, radius: 18)
                }
                .buttonStyle(Squish())
                if let id = router.check.itemID, let it = book.item(id) {
                    PriceForm(draft: $router.check, item: it, focus: $focus)
                    VerdictCard(item: it, draft: router.check)
                    if let e = router.check.entry {
                        HStack(spacing: 10) {
                            BigButton(title: "Save to the book", icon: "square.and.arrow.down.fill") {
                                book.log(e, to: it.id); focus = false
                                router.check.price = ""; router.check.sale = false
                                router.say("Saved. \(it.entries.count + 1) prices for \(it.name.lowercased())")
                            }
                            BigButton(title: "List", icon: "cart.fill.badge.plus", fill: K.paper, fg: K.ink) {
                                book.addToList(it.name, item: it.id); router.say("Added to your list")
                            }
                            .frame(width: 112)
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focus = false }.font(.ui(16, .bold)) } }
        .sheet(isPresented: $picking) {
            ItemPicker { it in router.check = Draft.start(it, book) }.presentationBackground(K.kraft).presentationCornerRadius(28)
        }
        .onAppear {
            if router.check.itemID == nil, let first = book.items.first(where: { $0.name == "Ground coffee" }) ?? book.items.first {
                router.check = Draft.start(first, book)
            }
        }
    }
}

// MARK: - Log a price sheet

struct LogPriceView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var draft = Draft()
    @State private var daysAgo = 0
    @FocusState private var focus: Bool
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let it = book.item(itemID) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Kicker("Log a price")
                                Text(it.name).font(.display(26, .black)).foregroundStyle(K.ink)
                            }
                            Spacer()
                            CircleButton(icon: "xmark") { dismiss() }
                        }
                        PriceForm(draft: $draft, item: it, focus: $focus)
                        HStack(spacing: 8) {
                            ForEach([(0, "Today"), (1, "Yesterday"), (7, "Last week")], id: \.0) { d in
                                Button { daysAgo = d.0 } label: { Chip(text: d.1, on: daysAgo == d.0) }.buttonStyle(Squish())
                            }
                        }
                        VerdictCard(item: it, draft: draft, compact: true)
                        BigButton(title: "Save price", icon: "checkmark") {
                            guard var e = draft.entry else { return }
                            e.day = Day.today - daysAgo
                            book.log(e, to: it.id)
                            router.say("Saved to the book")
                            dismiss()
                        }
                        .opacity(draft.entry == nil ? 0.45 : 1)
                        .disabled(draft.entry == nil)
                    }
                    .padding(20)
                    .onAppear { if draft.itemID == nil { draft = Draft.start(it, book); focus = true } }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focus = false }.font(.ui(16, .bold)) } }
        }
    }
}

// MARK: - Pick an item

struct ItemPicker: View {
    @Environment(Book.self) private var book
    @Environment(\.dismiss) private var dismiss
    var onPick: (Item) -> Void
    @State private var q = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Choose an item").font(.display(24, .black)).foregroundStyle(K.ink)
                Spacer()
                CircleButton(icon: "xmark") { dismiss() }
            }
            Field(placeholder: "Search your book", text: $q)
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(book.items.filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) }.sorted { $0.name < $1.name }) { it in
                        Button { onPick(it); dismiss() } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(it.name).font(.ui(16, .semibold)).foregroundStyle(K.ink)
                                    Text(it.category).font(.ui(12, .medium)).foregroundStyle(K.dim)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(K.dim)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.paper))
                        }
                        .buttonStyle(Squish(scale: 0.98))
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .padding(20)
    }
}
