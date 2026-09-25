import SwiftUI

struct ListView: View {
    @Environment(Book.self) private var book
    @Environment(Router.self) private var router
    @State private var adding = ""
    @FocusState private var focus: Bool

    private var suggestions: [Item] {
        guard adding.count >= 2 else { return [] }
        return Array(book.items.filter { $0.name.localizedCaseInsensitiveContains(adding) }.prefix(5))
    }

    var body: some View {
        let trip = book.plan()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Shopping list").font(.display(34, .black)).foregroundStyle(K.ink)
                    Spacer()
                    if !book.list.isEmpty {
                        ShareLink(item: shareText(trip)) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(K.ink)
                                .frame(width: 40, height: 40).background(Circle().fill(K.paper)).overlay(Circle().strokeBorder(K.line2, lineWidth: 1))
                        }
                    }
                }
                .padding(.top, 14)
                summary(trip)
                addBar
                storeToggles
                ForEach(trip.stops) { stop in stopCard(stop) }
                if book.list.contains(where: \.done) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { book.list.removeAll(where: \.done); book.save() }
                    } label: {
                        Label("Clear ticked items", systemImage: "trash").font(.ui(14.5, .bold)).foregroundStyle(K.red)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(K.red.opacity(0.4), lineWidth: 1.2))
                    }
                    .buttonStyle(Squish())
                }
                if book.list.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "cart").font(.system(size: 28, weight: .semibold)).foregroundStyle(K.green)
                        Text("Nothing on the list").font(.display(20)).foregroundStyle(K.ink)
                        Text("Add what you need. Pricebook sorts it by the store where each thing is usually cheapest.").font(.ui(14)).foregroundStyle(K.ink2)
                    }
                    .card(18)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder private func summary(_ trip: Trip) -> some View {
        if trip.total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Kicker("This trip, about")
                        Text(cash(trip.total)).font(.price(44)).foregroundStyle(K.ink).contentTransition(.numericText())
                    }
                    Spacer()
                    let n = trip.stops.filter { $0.shop != nil }.count
                    Text("\(n) \(n == 1 ? "store" : "stores")").font(.ui(13, .bold)).foregroundStyle(K.ink2)
                        .padding(.horizontal, 10).frame(height: 28).background(Capsule().fill(K.kraft))
                }
                if let sv = trip.saving, let s = trip.cheapestSingle, sv > 0.5 {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch").foregroundStyle(K.green)
                        Rich("Splitting it saves **\(cash(sv))** against buying everything at \(s.name), the cheapest single store.", size: 14, color: K.ink)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 14).fill(K.greenSoft))
                }
                // What the same list would cost at one store.
                let full = trip.singles.filter { $0.missing == 0 }
                if full.count >= 2, let hi = full.map(\.total).max(), hi > 0 {
                    VStack(spacing: 7) {
                        ForEach(full.sorted { $0.total < $1.total }) { s in
                            HStack(spacing: 8) {
                                Text(s.shop.name).font(.ui(12.5, .semibold)).foregroundStyle(K.ink2).frame(width: 70, alignment: .leading)
                                GeometryReader { g in
                                    Capsule().fill(Color(hexString: s.shop.color).opacity(0.85)).frame(width: max(8, g.size.width * CGFloat(s.total / hi)))
                                }
                                .frame(height: 10)
                                Text(cash0(s.total)).font(.price(14, .bold)).foregroundStyle(K.ink).frame(width: 52, alignment: .trailing)
                            }
                        }
                        Text("The same list at one store").font(.ui(11, .semibold)).foregroundStyle(K.dim).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .card(16, radius: 22)
        }
    }

    private var addBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundStyle(K.green)
                    TextField("", text: $adding, prompt: Text("Add something").foregroundStyle(K.dim))
                        .font(.ui(16.5, .medium)).foregroundStyle(K.ink).focused($focus).submitLabel(.done)
                        .onSubmit { add(nil) }
                }
                .padding(.horizontal, 14).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.paper))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.line2, lineWidth: 1))
            }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions) { it in
                            Button { add(it) } label: { Chip(text: it.name, icon: "plus") }.buttonStyle(Squish())
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: suggestions.map(\.id))
    }

    private func add(_ it: Item?) {
        let name = it?.name ?? adding.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let match = it ?? book.items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { book.addToList(match?.name ?? name, item: match?.id) }
        adding = ""
    }

    private var storeToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker("Going to")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(book.shops) { s in
                        let on = !book.skip.contains(s.id)
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                if on { if book.skip.count < book.shops.count - 1 { book.skip.insert(s.id) } } else { book.skip.remove(s.id) }
                                book.save()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 14, weight: .bold))
                                Text(s.name).font(.ui(14, .semibold)).strikethrough(!on)
                            }
                            .padding(.horizontal, 12).frame(height: 36)
                            .foregroundStyle(on ? .white : K.dim)
                            .background(Capsule().fill(on ? Color(hexString: s.color) : K.paper))
                            .overlay(Capsule().strokeBorder(on ? .clear : K.line2, lineWidth: 1))
                        }
                        .buttonStyle(Squish())
                        .sensoryFeedback(.selection, trigger: on)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func stopCard(_ stop: TripStop) -> some View {
        let color = stop.shop.map { Color(hexString: $0.color) } ?? K.ink2
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: stop.shop == nil ? "questionmark.circle.fill" : "storefront.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(RoundedRectangle(cornerRadius: 9).fill(color))
                VStack(alignment: .leading, spacing: 0) {
                    Text(stop.shop?.name ?? "Anywhere").font(.display(19)).foregroundStyle(K.ink)
                    Text(stop.shop == nil ? "No prices logged yet" : "\(stop.lines.filter { !$0.line.done }.count) to get").font(.ui(12, .semibold)).foregroundStyle(K.dim)
                }
                Spacer()
                if stop.total > 0 { Text(cash(stop.total)).font(.price(20)).foregroundStyle(K.ink).contentTransition(.numericText()) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(color.opacity(0.1))
            .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 4) }
            ForEach(stop.lines) { tl in
                LineRow(line: tl.line, cost: tl.cost, color: color)
                    .transition(.opacity)
                if tl.id != stop.lines.last?.id { Rectangle().fill(K.line).frame(height: 1).padding(.leading, 54) }
            }
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(K.paper))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(K.line, lineWidth: 1))
        .shadow(color: K.ink.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    private func shareText(_ trip: Trip) -> String {
        var out: [String] = []
        for s in trip.stops {
            out.append((s.shop?.name ?? "Anywhere").uppercased())
            for l in s.lines where !l.line.done { out.append("[ ] \(l.line.name)\(l.line.qty > 1 ? " × \(l.line.qty)" : "")") }
            out.append("")
        }
        return out.joined(separator: "\n")
    }
}

struct LineRow: View {
    @Environment(Book.self) private var book
    let line: ListLine
    let cost: Double?
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { toggle() }
            } label: {
                ZStack {
                    Circle().strokeBorder(line.done ? color : K.line2, lineWidth: 2).frame(width: 28, height: 28)
                    if line.done {
                        Circle().fill(color).frame(width: 28, height: 28)
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .black)).foregroundStyle(.white).transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(Squish(scale: 0.85))
            .sensoryFeedback(.impact(weight: .light), trigger: line.done)
            Text(line.name).font(.ui(16, .semibold)).foregroundStyle(line.done ? K.dim : K.ink).strikethrough(line.done, color: K.dim)
            if line.qty > 1 {
                Text("×\(line.qty)").font(.ui(12.5, .bold)).foregroundStyle(K.ink2).padding(.horizontal, 7).frame(height: 22).background(Capsule().fill(K.kraft))
            }
            Spacer()
            if let cost { Text(cash(cost)).font(.price(16, .bold)).foregroundStyle(line.done ? K.dim : K.ink2) }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { toggle() } }
        .contextMenu {
            Button { change(1) } label: { Label("One more", systemImage: "plus") }
            if line.qty > 1 { Button { change(-1) } label: { Label("One fewer", systemImage: "minus") } }
            Button(role: .destructive) { withAnimation { book.list.removeAll { $0.id == line.id }; book.save() } } label: { Label("Remove", systemImage: "trash") }
        }
    }
    private func toggle() {
        if let i = book.list.firstIndex(where: { $0.id == line.id }) { book.list[i].done.toggle(); book.save() }
    }
    private func change(_ d: Int) {
        if let i = book.list.firstIndex(where: { $0.id == line.id }) { book.list[i].qty = max(1, book.list[i].qty + d); book.save() }
    }
}
