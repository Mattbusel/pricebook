import SwiftUI

struct CompareView: View {
    @Environment(Router.self) private var router
    @FocusState private var focus: Bool
    private let letters = ["A", "B", "C", "D", "E", "F"]

    private var family: Family? {
        let fs = Set(router.options.filter { $0.unitPrice != nil }.map { $0.unit.family })
        return fs.count == 1 ? fs.first : nil
    }
    private var mixed: Bool { Set(router.options.filter { $0.unitPrice != nil }.map { $0.unit.family }).count > 1 }
    private var ranked: [(Int, Double)] {
        router.options.enumerated().compactMap { i, o in o.unitPrice.map { (i, $0) } }.sorted { $0.1 < $1.1 }
    }
    private var show: Unit {
        let u = router.options.first { $0.unitPrice != nil }?.unit ?? .oz
        switch u.family { case .weight: return u == .lb || u == .kg ? .lb : .oz; case .liquid: return .floz; case .count: return .ct }
    }

    var body: some View {
        @Bindable var router = router
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Which is cheaper?").font(.display(34, .black)).foregroundStyle(K.ink)
                    Text("Big pack or small, two for five, buy one get one. Type what the tags say.").font(.ui(14.5, .medium)).foregroundStyle(K.ink2)
                }
                .padding(.top, 14)
                summary
                ForEach(Array(router.options.indices), id: \.self) { i in
                    if i < router.options.count {
                        OptionCard(option: $router.options[i], letter: letters[min(i, 5)], rank: rank(i), best: ranked.first?.1, show: show,
                                   canRemove: router.options.count > 2, focus: $focus) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { _ = router.options.remove(at: i) }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity)))
                    }
                }
                if router.options.count < 6 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            var o = Option(); o.unit = router.options.last?.unit ?? .oz
                            router.options.append(o)
                        }
                    } label: {
                        HStack { Image(systemName: "plus"); Text("Add option \(letters[min(router.options.count, 5)])") }
                            .font(.ui(15.5, .bold)).foregroundStyle(K.ink2)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }
                    .buttonStyle(Squish())
                }
                usageCard
                Button("Clear and start again") {
                    withAnimation(.spring(response: 0.4)) { router.options = [Option(), Option()]; router.usage = "" }
                }
                .font(.ui(14, .bold)).foregroundStyle(K.dim).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focus = false }.font(.ui(16, .bold)) } }
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: ranked.map(\.0))
    }

    private func rank(_ i: Int) -> Int? { mixed ? nil : ranked.firstIndex { $0.0 == i } }

    @ViewBuilder private var summary: some View {
        if mixed {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(K.amber)
                Rich("These are measured in different ways, some by weight and some by volume or count. Use the same kind of unit for every option to compare them.", size: 14.5)
            }
            .card(14)
        } else if ranked.count >= 2, let w = ranked.first, let last = ranked.last {
            let wp = unitParts(w.1, show)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    Text(letters[min(w.0, 5)]).font(.display(40, .black)).foregroundStyle(K.ink)
                        .frame(width: 64, height: 64).background(Circle().fill(K.tag)).overlay(Circle().strokeBorder(K.ink, lineWidth: 2.5))
                    VStack(alignment: .leading, spacing: 3) {
                        Kicker("Best buy", color: K.green)
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(wp.0).font(.price(34)).foregroundStyle(K.ink).contentTransition(.numericText())
                            Text(wp.1).font(.price(17, .bold)).foregroundStyle(K.ink2)
                        }
                    }
                    Spacer()
                }
                Rich("Option **\(letters[min(last.0, 5)])** costs **\(pct(last.1 / w.1 - 1)) more** for the same amount.", size: 15)
                if let py = perYear, py > 0.5 {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill").foregroundStyle(K.green)
                        Rich("At your pace, buying **\(letters[min(w.0, 5)])** instead of **\(letters[min(ranked[1].0, 5)])** saves **\(cash(py)) a year**.", size: 14.5, color: K.ink)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 14).fill(K.greenSoft))
                }
            }
            .card(16, radius: 22)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    private var perYear: Double? {
        guard ranked.count >= 2, let n = parse(router.usage), n > 0, let fam = family, router.usageUnit.family == fam else { return nil }
        let perDay = n * router.usageUnit.factor / (router.usageWeekly ? 7 : 30.44)
        return (ranked[1].1 - ranked[0].1) * perDay * 365
    }

    private var usageCard: some View {
        @Bindable var router = router
        return VStack(alignment: .leading, spacing: 10) {
            Kicker("How much you use (optional)")
            HStack(spacing: 8) {
                TextField("", text: $router.usage, prompt: Text("2").foregroundStyle(K.dim))
                    .font(.price(22)).foregroundStyle(K.ink).keyboardType(.decimalPad).focused($focus)
                    .frame(width: 70).padding(.horizontal, 12).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 12).fill(K.kraft))
                Menu {
                    ForEach((family ?? .weight).units) { u in Button(u.word) { router.usageUnit = u } }
                } label: {
                    HStack(spacing: 4) { Text(router.usageUnit.word).font(.ui(15, .bold)); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold)) }
                        .foregroundStyle(K.ink).padding(.horizontal, 12).frame(height: 46).background(RoundedRectangle(cornerRadius: 12).fill(K.kraft))
                }
                Picker("", selection: $router.usageWeekly) {
                    Text("a month").tag(false)
                    Text("a week").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Text("Add this and Pricebook turns the difference into money per year.").font(.ui(12.5)).foregroundStyle(K.dim)
        }
        .card(16)
    }
}

struct OptionCard: View {
    @Binding var option: Option
    let letter: String
    let rank: Int?
    let best: Double?
    let show: Unit
    let canRemove: Bool
    var focus: FocusState<Bool>.Binding
    var remove: () -> Void

    var body: some View {
        let isBest = rank == 0
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(letter).font(.display(20, .black)).foregroundStyle(isBest ? K.ink : K.ink2)
                    .frame(width: 36, height: 36).background(Circle().fill(isBest ? K.tag : K.kraft))
                Menu {
                    ForEach(Deal.allCases, id: \.self) { d in Button(d.rawValue) { withAnimation(.spring(response: 0.3)) { option.deal = d } } }
                } label: {
                    HStack(spacing: 5) { Text(option.deal.rawValue).font(.ui(13.5, .bold)); Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)) }
                        .foregroundStyle(option.deal == .none ? K.ink2 : .white)
                        .padding(.horizontal, 11).frame(height: 30)
                        .background(Capsule().fill(option.deal == .none ? K.kraft : K.red))
                }
                Spacer()
                if let r = rank, let up = option.unitPrice, let best {
                    if r == 0 {
                        Text("BEST BUY").font(.kick(10)).foregroundStyle(K.ink).padding(.horizontal, 9).frame(height: 24)
                            .background(K.tag).overlay(alignment: .top) { Rectangle().fill(K.ink).frame(height: 2) }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .rotationEffect(.degrees(-4))
                            .transition(.scale(scale: 1.8).combined(with: .opacity))
                    } else {
                        Text("+" + pct(up / best - 1)).font(.ui(13, .bold)).foregroundStyle(K.red).padding(.horizontal, 9).frame(height: 24).background(Capsule().fill(K.redSoft))
                    }
                }
                if canRemove {
                    Button(action: remove) { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(K.dim).frame(width: 28, height: 28).background(Circle().fill(K.kraft)) }
                }
            }
            HStack(spacing: 8) {
                switch option.deal {
                case .multi:
                    box("How many", $option.n, width: 64)
                    Text("for").font(.ui(14, .semibold)).foregroundStyle(K.dim)
                    box(currencySymbol, $option.total)
                case .percent:
                    box(currencySymbol + " price", $option.price)
                    box("% off", $option.percent, width: 80)
                default:
                    box(currencySymbol + (option.deal == .bogo ? " each" : " price"), $option.price)
                }
            }
            HStack(spacing: 8) {
                box("Size", $option.size)
                Menu {
                    ForEach(Unit.allCases) { u in Button(u.word) { option.unit = u } }
                } label: {
                    HStack(spacing: 4) { Text(option.unit.word).font(.ui(15, .bold)); Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold)) }
                        .foregroundStyle(K.ink).padding(.horizontal, 12).frame(height: 46).background(RoundedRectangle(cornerRadius: 12).fill(K.kraft))
                }
                HStack(spacing: 0) {
                    Button { if option.pack > 1 { option.pack -= 1 } } label: { Image(systemName: "minus").frame(width: 30, height: 46) }
                    Text("×\(option.pack)").font(.price(17)).frame(minWidth: 30).contentTransition(.numericText())
                    Button { option.pack += 1 } label: { Image(systemName: "plus").frame(width: 30, height: 46) }
                }
                .font(.system(size: 12, weight: .bold)).foregroundStyle(K.ink)
                .background(RoundedRectangle(cornerRadius: 12).fill(K.kraft))
                box("Coupon", $option.coupon, width: 78)
            }
            HStack {
                if let up = option.unitPrice {
                    let p = unitParts(up, show)
                    Text("Works out to").font(.ui(13, .semibold)).foregroundStyle(K.dim)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(p.0).font(.price(24)).foregroundStyle(isBest ? K.green : K.ink).contentTransition(.numericText())
                        Text(p.1).font(.price(13, .bold)).foregroundStyle(K.ink2)
                    }
                    if let e = option.each, option.deal != .none || parse(option.coupon) != nil {
                        Text("(\(cash(e)) each)").font(.ui(12, .semibold)).foregroundStyle(K.dim)
                    }
                } else {
                    Text("Type a price and a size").font(.ui(13, .semibold)).foregroundStyle(K.dim)
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(K.paper).shadow(color: (isBest ? K.green : K.ink).opacity(isBest ? 0.18 : 0.06), radius: 12, x: 0, y: 6))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(isBest ? K.green : K.line, lineWidth: isBest ? 2.5 : 1))
        .scaleEffect(isBest ? 1 : 0.985)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isBest)
        .sensoryFeedback(.impact(weight: .light), trigger: isBest)
    }

    private func box(_ label: String, _ text: Binding<String>, width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased()).font(.kick(8.5)).foregroundStyle(K.dim)
            TextField("", text: text, prompt: Text("-").foregroundStyle(K.dim.opacity(0.6)))
                .font(.price(20)).foregroundStyle(K.ink).keyboardType(.decimalPad).focused(focus)
        }
        .padding(.horizontal, 10).frame(height: 46)
        .frame(maxWidth: width ?? .infinity, alignment: .leading)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 12).fill(K.kraft))
    }
}
