import SwiftUI

/// Kraft paper, grocer green, shelf-tag yellow. Prices set like the tags on a shelf edge.
enum K {
    static let kraft = Color(hex: 0xF1E8D6)
    static let kraft2 = Color(hex: 0xE6D9BF)
    static let kraft3 = Color(hex: 0xD9C8A6)
    static let paper = Color(hex: 0xFFFCF5)
    static let ink = Color(hex: 0x1D2921)
    static let ink2 = Color(hex: 0x1D2921).opacity(0.68)
    static let dim = Color(hex: 0x1D2921).opacity(0.45)
    static let line = Color(hex: 0x1D2921).opacity(0.10)
    static let line2 = Color(hex: 0x1D2921).opacity(0.18)
    static let green = Color(hex: 0x2E6B3F)
    static let green2 = Color(hex: 0x3E8C54)
    static let greenDeep = Color(hex: 0x1F4D2C)
    static let greenSoft = Color(hex: 0xDDEAD5)
    static let tag = Color(hex: 0xF8D64B)
    static let tagDeep = Color(hex: 0xE3B91C)
    static let red = Color(hex: 0xB43E2A)
    static let redSoft = Color(hex: 0xF5DDD4)
    static let amber = Color(hex: 0xB47414)
    static let amberSoft = Color(hex: 0xF6E6C6)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: alpha)
    }
    init(hexString: String) { self.init(hex: UInt32(hexString, radix: 16) ?? 0x777777) }
}

extension Verdict {
    var color: Color {
        switch self {
        case .stock, .good: return K.green
        case .normal: return K.ink2
        case .fake: return K.red
        case .high: return K.amber
        case .none: return K.dim
        }
    }
    var soft: Color {
        switch self {
        case .stock, .good: return K.greenSoft
        case .normal: return K.kraft2
        case .fake: return K.redSoft
        case .high: return K.amberSoft
        case .none: return K.kraft2
        }
    }
    var icon: String {
        switch self {
        case .stock: return "arrow.down.to.line.circle.fill"
        case .good: return "hand.thumbsup.circle.fill"
        case .normal: return "equal.circle.fill"
        case .fake: return "exclamationmark.octagon.fill"
        case .high: return "arrow.up.circle.fill"
        case .none: return "sparkles"
        }
    }
}

extension Font {
    static func display(_ s: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: s, weight: w, design: .serif) }
    static func price(_ s: CGFloat, _ w: Font.Weight = .heavy) -> Font { .system(size: s, weight: w).width(.condensed).monospacedDigit() }
    static func ui(_ s: CGFloat, _ w: Font.Weight = .medium) -> Font { .system(size: s, weight: w) }
    static func kick(_ s: CGFloat = 11) -> Font { .system(size: s, weight: .heavy).width(.expanded) }
}

struct Kicker: View {
    let text: String
    var color: Color = K.dim
    init(_ t: String, color: Color = K.dim) { text = t; self.color = color }
    var body: some View { Text(text.uppercased()).font(.kick()).tracking(1.2).foregroundStyle(color) }
}

/// Markdown-bold text for the reasons and summaries.
struct Rich: View {
    let s: String
    var size: CGFloat = 15
    var color: Color = K.ink2
    init(_ s: String, size: CGFloat = 15, color: Color = K.ink2) { self.s = s; self.size = size; self.color = color }
    var body: some View { Text(LocalizedStringKey(s)).font(.ui(size, .regular)).foregroundStyle(color).fixedSize(horizontal: false, vertical: true) }
}

// MARK: - Backgrounds

struct Kraft: View {
    var body: some View {
        ZStack {
            K.kraft
            Canvas { ctx, size in
                var g = SeededRNG(seed: 11)
                // Paper fibres: short, faint strokes at random angles.
                for _ in 0..<900 {
                    let x = CGFloat(g.next()) * size.width, y = CGFloat(g.next()) * size.height
                    let a = CGFloat(g.next()) * .pi, l = CGFloat(3 + g.next() * 9)
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + cos(a) * l, y: y + sin(a) * l))
                    ctx.stroke(p, with: .color(g.next() > 0.5 ? K.ink.opacity(0.045) : Color.white.opacity(0.35)), lineWidth: 0.6)
                }
            }
            LinearGradient(colors: [Color.white.opacity(0.35), .clear, K.kraft2.opacity(0.35)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

struct SeededRNG {
    var seed: UInt64
    mutating func next() -> Double {
        seed = (seed &* 6364136223846793005 &+ 1442695040888963407)
        return Double((seed >> 33) % 1_000_000) / 1_000_000
    }
}

extension View {
    /// White card on kraft, with a soft paper shadow.
    func card(_ pad: CGFloat = 16, radius: CGFloat = 20) -> some View {
        self.padding(pad)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(K.paper)
                    .shadow(color: K.ink.opacity(0.07), radius: 0, x: 0, y: 2)
                    .shadow(color: K.ink.opacity(0.06), radius: 14, x: 0, y: 8)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(K.line, lineWidth: 1))
    }
}

// MARK: - Shelf tag

enum TagStyle { case yellow, white, green, red }

/// The price tag on a shelf edge: a dark rule on top, a small label, a big condensed price.
struct ShelfTag: View {
    var label: String? = nil
    let price: String
    var per: String = ""
    var style: TagStyle = .yellow
    var big: CGFloat = 28
    var foot: String? = nil
    private var bg: Color { switch style { case .yellow: return K.tag; case .white: return K.paper; case .green: return K.green; case .red: return K.redSoft } }
    private var fg: Color { switch style { case .green: return .white; case .red: return K.red; default: return K.ink } }
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let label { Text(label.uppercased()).font(.kick(9)).tracking(0.8).foregroundStyle(fg.opacity(0.7)) }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(price).font(.price(big)).foregroundStyle(fg).contentTransition(.numericText())
                Text(per).font(.price(big * 0.46, .bold)).foregroundStyle(fg.opacity(0.75))
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            if let foot { Text(foot).font(.ui(10.5, .semibold)).foregroundStyle(fg.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.8) }
        }
        .padding(.horizontal, 10).padding(.top, 7).padding(.bottom, 6)
        .background(bg)
        .overlay(alignment: .top) { Rectangle().fill(style == .green ? K.greenDeep : K.ink).frame(height: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .compositingGroup()
        .shadow(color: K.ink.opacity(0.14), radius: 0, x: 0, y: 1.5)
    }
}

// MARK: - Rubber stamp

struct Stamp: View {
    let verdict: Verdict
    var size: CGFloat = 30
    var body: some View {
        Text(verdict.title.uppercased())
            .font(.system(size: size, weight: .black).width(.condensed))
            .tracking(1.5)
            .foregroundStyle(verdict.color)
            .padding(.horizontal, size * 0.5).padding(.vertical, size * 0.18)
            .background(RoundedRectangle(cornerRadius: size * 0.22).fill(verdict.soft.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: size * 0.22).strokeBorder(verdict.color, lineWidth: size * 0.1))
            .overlay(RoundedRectangle(cornerRadius: size * 0.14).strokeBorder(verdict.color.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2])).padding(size * 0.16))
            .rotationEffect(.degrees(-5))
    }
}

// MARK: - Bits

struct Dot: View {
    let color: Color
    var size: CGFloat = 9
    var body: some View { Circle().fill(color).frame(width: size, height: size).overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1)) }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color = K.green
    var body: some View {
        GeometryReader { g in
            if values.count >= 2, let lo = values.min(), let hi = values.max() {
                let span = max(hi - lo, hi * 0.04)
                let pts = values.enumerated().map { i, v in
                    CGPoint(x: g.size.width * CGFloat(i) / CGFloat(values.count - 1), y: g.size.height * (1 - CGFloat((v - lo) / span)) * 0.8 + g.size.height * 0.1)
                }
                Path { p in p.addLines(pts) }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                Circle().fill(color).frame(width: 5, height: 5).position(pts.last!)
            }
        }
    }
}

struct Chip: View {
    let text: String
    var on = false
    var color: Color = K.ink
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
            Text(text).font(.ui(13.5, .semibold)).lineLimit(1)
        }
        .padding(.horizontal, 12).frame(height: 32)
        .foregroundStyle(on ? .white : K.ink)
        .background(Capsule().fill(on ? color : K.paper))
        .overlay(Capsule().strokeBorder(on ? .clear : K.line2, lineWidth: 1))
    }
}

struct Squish: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct BigButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = K.green
    var fg: Color = .white
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .bold)) }
                Text(title).font(.ui(16.5, .bold))
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .foregroundStyle(fg)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill).shadow(color: (fill == K.paper ? K.ink.opacity(0.1) : fill.opacity(0.35)), radius: 10, x: 0, y: 6))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.black.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(Squish())
    }
}

struct CircleButton: View {
    let icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(K.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(K.paper).shadow(color: K.ink.opacity(0.08), radius: 6, x: 0, y: 3)).overlay(Circle().strokeBorder(K.line2, lineWidth: 1))
        }
        .buttonStyle(Squish(scale: 0.9))
    }
}

/// A text field dressed for kraft paper.
struct Field: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var font: Font = .ui(17, .semibold)
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(K.dim))
            .font(font).foregroundStyle(K.ink)
            .keyboardType(keyboard)
            .padding(.horizontal, 14).frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.paper))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.line2, lineWidth: 1))
    }
}

struct Toast: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(K.tag)
            Text(text).font(.ui(15, .semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 18).frame(height: 46)
        .background(Capsule().fill(K.ink))
        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
    }
}

extension Book {
    func color(_ shop: String) -> Color { Color(hexString: self.shop(shop)?.color ?? "777777") }
}
