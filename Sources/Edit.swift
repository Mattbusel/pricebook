import SwiftUI

// MARK: - New item

struct NewItemView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let seed: NewItemSeed
    var onCreate: ((Item) -> Void)? = nil
    @State private var name = ""
    @State private var category = ""
    @State private var family: Family = .weight
    @State private var show: Unit = .oz
    @State private var code = ""
    @FocusState private var focus: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("New item").font(.display(28, .black)).foregroundStyle(K.ink)
                        Spacer()
                        CircleButton(icon: "xmark") { dismiss() }
                    }
                    group("What is it") {
                        Field(placeholder: "e.g. Ground coffee", text: $name).focused($focus)
                    }
                    group("Aisle") {
                        FlowChips(options: book.categories, selection: $category)
                    }
                    group("Priced") {
                        HStack(spacing: 8) {
                            ForEach(Family.allCases) { f in
                                Button {
                                    withAnimation(.spring(response: 0.3)) { family = f; show = f.units[0] }
                                } label: {
                                    Text(f.label).font(.ui(14, .bold)).frame(maxWidth: .infinity).frame(height: 44)
                                        .foregroundStyle(family == f ? .white : K.ink)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(family == f ? K.ink : K.paper))
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(family == f ? .clear : K.line2, lineWidth: 1))
                                }
                                .buttonStyle(Squish())
                            }
                        }
                        HStack(spacing: 8) {
                            Text("Compare it per").font(.ui(14, .semibold)).foregroundStyle(K.ink2)
                            ForEach(family.units) { u in
                                Button { show = u } label: { Chip(text: u.word, on: show == u, color: K.green) }.buttonStyle(Squish())
                            }
                        }
                    }
                    group("Barcode (optional)") {
                        Field(placeholder: "Scan it later, or type the numbers", text: $code, keyboard: .numberPad, font: .system(size: 17, weight: .semibold, design: .monospaced))
                    }
                    BigButton(title: "Add to the book", icon: "checkmark") { create() }
                        .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            name = seed.name; code = seed.code
            if category.isEmpty { category = book.categories.first ?? "Pantry" }
            focus = true
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { Kicker(title); c() }
    }

    private func create() {
        var it = Item(name: name.trimmingCharacters(in: .whitespaces), category: category.isEmpty ? "Pantry" : category, family: family, show: show)
        let c = normalizeCode(code)
        if !c.isEmpty { it.barcodes = [c] }
        book.update(it)
        if !c.isEmpty { book.link(code: c, to: it.id) }
        dismiss()
        if let onCreate { onCreate(it) } else {
            router.path.append(it.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { router.logging = it.id }
        }
    }
}

/// Chips that wrap onto as many lines as they need.
struct FlowChips: View {
    let options: [String]
    @Binding var selection: String
    var body: some View {
        Flow(spacing: 8) {
            ForEach(options, id: \.self) { o in
                Button { withAnimation(.spring(response: 0.3)) { selection = o } } label: { Chip(text: o, on: selection == o, color: K.green) }
                    .buttonStyle(Squish())
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct Flow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += s.width + spacing; row = max(row, s.height)
        }
        return CGSize(width: maxW, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; row = max(row, s.height)
        }
    }
}

// MARK: - Edit item

struct EditItemView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var it: Item? = nil
    @State private var amount = ""
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let binding = Binding($it) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Edit item").font(.display(28, .black)).foregroundStyle(K.ink)
                            Spacer()
                            CircleButton(icon: "xmark") { dismiss() }
                        }
                        VStack(alignment: .leading, spacing: 10) { Kicker("Name"); Field(placeholder: "Name", text: binding.name) }
                        VStack(alignment: .leading, spacing: 10) { Kicker("Aisle"); FlowChips(options: book.categories, selection: binding.category) }
                        VStack(alignment: .leading, spacing: 10) {
                            Kicker("Compare it per")
                            HStack(spacing: 8) {
                                ForEach(binding.wrappedValue.family.units) { u in
                                    Button { binding.wrappedValue.show = u } label: { Chip(text: u.word, on: binding.wrappedValue.show == u, color: K.green) }.buttonStyle(Squish())
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Kicker("How much you use")
                            HStack(spacing: 8) {
                                TextField("", text: $amount, prompt: Text("e.g. 2").foregroundStyle(K.dim))
                                    .font(.price(22)).foregroundStyle(K.ink).keyboardType(.decimalPad)
                                    .frame(width: 70).padding(.horizontal, 12).frame(height: 46)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(K.paper))
                                Menu {
                                    ForEach(binding.wrappedValue.family.units) { u in Button(u.word) { setUsage(unit: u) } }
                                } label: {
                                    HStack(spacing: 4) { Text((binding.wrappedValue.usage?.unit ?? binding.wrappedValue.show).word).font(.ui(15, .bold)); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold)) }
                                        .foregroundStyle(K.ink).padding(.horizontal, 12).frame(height: 46).background(RoundedRectangle(cornerRadius: 12).fill(K.paper))
                                }
                                Picker("", selection: Binding(get: { binding.wrappedValue.usage?.weekly ?? false }, set: { setUsage(weekly: $0) })) {
                                    Text("a month").tag(false); Text("a week").tag(true)
                                }
                                .pickerStyle(.segmented)
                            }
                            Text("Used for yearly savings and for how many to buy when it is on sale.").font(.ui(12.5)).foregroundStyle(K.dim)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Kicker("Barcodes")
                            if binding.wrappedValue.barcodes.isEmpty {
                                Text("None yet. Scan the item and pick it from your book to link one.").font(.ui(14)).foregroundStyle(K.ink2)
                            }
                            ForEach(binding.wrappedValue.barcodes, id: \.self) { c in
                                HStack {
                                    Image(systemName: "barcode").foregroundStyle(K.ink2)
                                    Text(prettyCode(c)).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(K.ink)
                                    Spacer()
                                    Button { binding.wrappedValue.barcodes.removeAll { $0 == c } } label: { Image(systemName: "minus.circle.fill").foregroundStyle(K.red) }
                                }
                                .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(K.paper))
                            }
                        }
                        BigButton(title: "Save", icon: "checkmark") {
                            if var x = it {
                                if let a = parse(amount), a > 0 { x.usage = Usage(amount: a, unit: x.usage?.unit ?? x.show, weekly: x.usage?.weekly ?? false) }
                                else { x.usage = nil }
                                book.update(x)
                            }
                            dismiss()
                        }
                        Button("Delete this item") { confirmDelete = true }
                            .font(.ui(15, .bold)).foregroundStyle(K.red).frame(maxWidth: .infinity).padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("Delete this item and all its prices?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    book.deleteItem(itemID); router.path.removeAll { $0 == itemID }; dismiss()
                }
            }
        }
        .onAppear {
            it = book.item(itemID)
            if let u = it?.usage { amount = num(u.amount) }
        }
    }

    private func setUsage(unit: Unit? = nil, weekly: Bool? = nil) {
        guard var x = it else { return }
        var u = x.usage ?? Usage(amount: parse(amount) ?? 0, unit: x.show, weekly: false)
        if let unit { u.unit = unit }
        if let weekly { u.weekly = weekly }
        x.usage = u
        it = x
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(Book.self) private var book
    @Environment(\.dismiss) private var dismiss
    @State private var newShop = ""
    @State private var newCat = ""
    @State private var erase = false
    @State private var csvURL: URL? = nil

    var body: some View {
        @Bindable var book = book
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("Stores & settings").font(.display(28, .black)).foregroundStyle(K.ink)
                        Spacer()
                        CircleButton(icon: "xmark") { dismiss() }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Kicker("Your stores")
                        ForEach($book.shops) { $s in
                            HStack(spacing: 10) {
                                Button {
                                    let i = Book.palette.firstIndex(of: s.color) ?? -1
                                    withAnimation(.spring(response: 0.3)) { s.color = Book.palette[(i + 1) % Book.palette.count] }
                                } label: {
                                    Circle().fill(Color(hexString: s.color)).frame(width: 30, height: 30).overlay(Circle().strokeBorder(.white, lineWidth: 2)).shadow(color: .black.opacity(0.15), radius: 2)
                                }
                                .buttonStyle(Squish(scale: 0.85))
                                TextField("Store name", text: $s.name).font(.ui(16.5, .semibold)).foregroundStyle(K.ink)
                                let n = book.items.reduce(0) { a, it in a + it.entries.filter { $0.shop == s.id }.count }
                                Text("\(n)").font(.ui(12, .bold)).foregroundStyle(K.dim)
                                if book.shops.count > 1 {
                                    Button { withAnimation { book.removeShop(s.id) } } label: { Image(systemName: "minus.circle.fill").foregroundStyle(K.red.opacity(0.8)) }
                                }
                            }
                            .padding(.horizontal, 12).frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 14).fill(K.paper))
                        }
                        HStack(spacing: 10) {
                            Field(placeholder: "Add a store", text: $newShop)
                            Button {
                                let t = newShop.trimmingCharacters(in: .whitespaces)
                                if !t.isEmpty { withAnimation { book.addShop(t) }; newShop = "" }
                            } label: { Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).frame(width: 50, height: 50).background(RoundedRectangle(cornerRadius: 14).fill(K.green)) }
                        }
                        Text("Tap a colour dot to change it. Removing a store also removes the prices logged there.").font(.ui(12)).foregroundStyle(K.dim)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Kicker("Aisles")
                        Flow(spacing: 8) {
                            ForEach(book.categories, id: \.self) { c in
                                Button { withAnimation { book.categories.removeAll { $0 == c }; book.save() } } label: { Chip(text: c, icon: "xmark") }.buttonStyle(Squish())
                            }
                        }
                        HStack(spacing: 10) {
                            Field(placeholder: "Add an aisle", text: $newCat)
                            Button {
                                let t = newCat.trimmingCharacters(in: .whitespaces)
                                if !t.isEmpty, !book.categories.contains(t) { withAnimation { book.categories.append(t); book.save() }; newCat = "" }
                            } label: { Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).frame(width: 50, height: 50).background(RoundedRectangle(cornerRadius: 14).fill(K.green)) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Kicker("Your data")
                        if let csvURL {
                            ShareLink(item: csvURL) {
                                Label("Export every price as a spreadsheet (CSV)", systemImage: "tablecells").font(.ui(15.5, .semibold)).foregroundStyle(K.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).frame(height: 52)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(K.paper))
                            }
                        }
                        Button { erase = true } label: {
                            Label("Erase everything", systemImage: "trash").font(.ui(15.5, .semibold)).foregroundStyle(K.red)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).frame(height: 52)
                                .background(RoundedRectangle(cornerRadius: 14).fill(K.paper))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No account, no ads, no tracking.").font(.display(17)).foregroundStyle(K.ink)
                        Text("Everything you log stays on this phone. Pricebook never connects to the internet.").font(.ui(14)).foregroundStyle(K.ink2)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("Erase every item, price and list? This cannot be undone.", isPresented: $erase, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) { book.eraseAll(); dismiss() }
            }
        }
        .onAppear { csvURL = book.csv() }
        .onChange(of: book.shops) { book.save() }
    }
}
