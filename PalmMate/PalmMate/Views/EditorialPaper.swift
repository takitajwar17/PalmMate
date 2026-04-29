import SwiftUI

// MARK: - Design tokens (editorial occult-atlas)

enum P {
    static let paper       = Color(red: 0.949, green: 0.922, blue: 0.863)   // #F2EBDC
    static let paperDeep   = Color(red: 0.910, green: 0.875, blue: 0.797)   // #E8DFCB
    static let paperBright = Color(red: 0.980, green: 0.961, blue: 0.910)   // #FAF5E8
    static let ink         = Color(red: 0.102, green: 0.086, blue: 0.067)   // #1A1611
    static let inkSoft     = Color(red: 0.227, green: 0.200, blue: 0.165)   // #3A332A
    static let inkMuted    = Color(red: 0.431, green: 0.388, blue: 0.341)   // #6E6357
    static let inkFaded    = Color(red: 0.580, green: 0.529, blue: 0.463)   // #948776
    static let rule        = Color(red: 0.722, green: 0.675, blue: 0.592)   // #B8AC97
    static let ruleSoft    = Color(red: 0.839, green: 0.800, blue: 0.714)   // #D6CCB6
    static let vermillion  = Color(red: 0.722, green: 0.192, blue: 0.129)   // #B83121
    static let night       = Color(red: 0.078, green: 0.067, blue: 0.051)   // #14110D
    static let moonlight   = Color(red: 0.914, green: 0.867, blue: 0.773)   // #E9DDC5
}

// MARK: - Legacy shim (used by ResultView / LockedSection)

enum EditorialPaper {
    static let paper      = P.paper
    static let ink        = P.ink
    static let inkMuted   = P.inkMuted
    static let rule       = P.rule
    static let gold       = Color(red: 0.549, green: 0.416, blue: 0.122)
    static let cardFill   = P.paperBright
    static let cardStroke = P.ruleSoft
}

// MARK: - Paper background

struct PaperBackground: View {
    var body: some View {
        ZStack {
            P.paper.ignoresSafeArea()
            RadialGradient(
                colors: [P.vermillion.opacity(0.04), .clear],
                center: .topLeading, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Night background (analyzing screen)

struct NightBackground: View {
    var body: some View {
        ZStack {
            P.night.ignoresSafeArea()
            RadialGradient(
                colors: [P.vermillion.opacity(0.10), .clear],
                center: .top, startRadius: 0, endRadius: 400
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Custom fonts

enum F {
    static func display(_ size: CGFloat, italic: Bool = false) -> Font {
        let name = italic ? "CormorantGaramond-MediumItalic" : "CormorantGaramond-Medium"
        return Font.custom(name, size: size)
    }
    static func displayLight(_ size: CGFloat) -> Font {
        Font.custom("CormorantGaramond-Light", size: size)
    }
    static func body(_ size: CGFloat, italic: Bool = false) -> Font {
        let name = italic ? "EBGaramond12-Italic" : "EBGaramond12-Regular"
        return Font.custom(name, size: size)
    }
    static func mono(_ size: CGFloat) -> Font {
        Font.custom("JetBrainsMono-Regular", size: size)
    }
}

// MARK: - Shared view atoms

struct HairlineRule: View {
    var body: some View {
        Rectangle()
            .frame(height: 0.5)
            .foregroundStyle(P.rule)
    }
}

struct OrnamentRule: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().frame(height: 0.5).foregroundStyle(P.rule)
            Text(label.uppercased())
                .font(F.mono(9))
                .foregroundStyle(P.inkMuted)
                .fixedSize()
            Rectangle().frame(height: 0.5).foregroundStyle(P.rule)
        }
    }
}

struct EyebrowText: View {
    let text: String
    var color: Color = P.inkMuted

    var body: some View {
        Text(text.uppercased())
            .font(F.mono(9))
            .foregroundStyle(color)
            .tracking(2)
    }
}

struct StampBadge: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(F.mono(9))
            .foregroundStyle(P.vermillion)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                Rectangle().stroke(P.vermillion, lineWidth: 0.8)
            )
    }
}

// MARK: - Ink button (primary / ghost variants)

struct InkButton: View {
    enum Style { case primary, accent, ghost }
    let title: String
    let style: Style
    var icon: String? = nil
    let action: () -> Void

    var bgColor: Color {
        switch style {
        case .primary: return P.ink
        case .accent:  return P.vermillion
        case .ghost:   return .clear
        }
    }
    var fgColor: Color {
        switch style {
        case .primary, .accent: return P.paperBright
        case .ghost: return P.ink
        }
    }
    var borderColor: Color {
        style == .ghost ? P.ink : .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .light))
                }
                Text(title.uppercased())
                    .font(F.mono(11))
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(bgColor)
            .foregroundStyle(fgColor)
            .overlay(Rectangle().stroke(borderColor, lineWidth: 0.8))
        }
    }
}

// MARK: - Engraved palm SVG

struct PalmEngraving: View {
    var size: CGFloat = 160
    var strokeColor: Color = P.ink
    var lineColor: Color = P.vermillion
    var showLines: Bool = true
    var hatch: Bool = true
    var mirror: Bool = false

    var body: some View {
        Canvas { ctx, _ in
            let s = size / 200.0
            ctx.translateBy(x: mirror ? size : 0, y: 0)
            ctx.scaleBy(x: mirror ? -s : s, y: s)
            drawPalm(ctx: ctx)
        }
        .frame(width: size, height: size * 1.15)
    }

    private func drawPalm(ctx: GraphicsContext) {
        // Hand outline
        var outline = Path()
        outline.move(to: CGPoint(x: 60, y: 220))
        outline.addCurve(to: CGPoint(x: 38, y: 150),
                         control1: CGPoint(x: 50, y: 200), control2: CGPoint(x: 40, y: 175))
        outline.addCurve(to: CGPoint(x: 40, y: 100),
                         control1: CGPoint(x: 36, y: 130), control2: CGPoint(x: 38, y: 115))
        outline.addLine(to: CGPoint(x: 38, y: 60))
        outline.addCurve(to: CGPoint(x: 54, y: 41),
                         control1: CGPoint(x: 37, y: 48), control2: CGPoint(x: 45, y: 40))
        outline.addCurve(to: CGPoint(x: 66, y: 60),
                         control1: CGPoint(x: 62, y: 42), control2: CGPoint(x: 66, y: 50))
        outline.addLine(to: CGPoint(x: 68, y: 95))
        outline.addLine(to: CGPoint(x: 70, y: 35))
        outline.addCurve(to: CGPoint(x: 87, y: 15),
                         control1: CGPoint(x: 70, y: 22), control2: CGPoint(x: 78, y: 15))
        outline.addCurve(to: CGPoint(x: 102, y: 35),
                         control1: CGPoint(x: 96, y: 15), control2: CGPoint(x: 102, y: 22))
        outline.addLine(to: CGPoint(x: 100, y: 95))
        outline.addLine(to: CGPoint(x: 106, y: 28))
        outline.addCurve(to: CGPoint(x: 124, y: 12),
                         control1: CGPoint(x: 107, y: 16), control2: CGPoint(x: 116, y: 10))
        outline.addCurve(to: CGPoint(x: 134, y: 34),
                         control1: CGPoint(x: 132, y: 14), control2: CGPoint(x: 136, y: 22))
        outline.addLine(to: CGPoint(x: 128, y: 100))
        outline.addLine(to: CGPoint(x: 138, y: 50))
        outline.addCurve(to: CGPoint(x: 155, y: 38),
                         control1: CGPoint(x: 140, y: 40), control2: CGPoint(x: 148, y: 36))
        outline.addCurve(to: CGPoint(x: 162, y: 62),
                         control1: CGPoint(x: 163, y: 40), control2: CGPoint(x: 166, y: 50))
        outline.addLine(to: CGPoint(x: 152, y: 110))
        outline.addCurve(to: CGPoint(x: 168, y: 134),
                         control1: CGPoint(x: 158, y: 115), control2: CGPoint(x: 164, y: 122))
        outline.addCurve(to: CGPoint(x: 162, y: 188),
                         control1: CGPoint(x: 172, y: 148), control2: CGPoint(x: 170, y: 168))
        outline.addCurve(to: CGPoint(x: 120, y: 222),
                         control1: CGPoint(x: 154, y: 208), control2: CGPoint(x: 138, y: 222))
        outline.closeSubpath()

        ctx.stroke(outline, with: .color(strokeColor),
                   style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

        if showLines {
            // Heart line
            var heart = Path()
            heart.move(to: CGPoint(x: 50, y: 130))
            heart.addQuadCurve(to: CGPoint(x: 130, y: 125), control: CGPoint(x: 90, y: 120))
            heart.addQuadCurve(to: CGPoint(x: 165, y: 130), control: CGPoint(x: 147, y: 128))
            ctx.stroke(heart, with: .color(lineColor),
                       style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

            // Head line
            var head = Path()
            head.move(to: CGPoint(x: 52, y: 152))
            head.addQuadCurve(to: CGPoint(x: 140, y: 158), control: CGPoint(x: 95, y: 148))
            ctx.stroke(head, with: .color(lineColor),
                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

            // Life line
            var life = Path()
            life.move(to: CGPoint(x: 58, y: 130))
            life.addCurve(to: CGPoint(x: 60, y: 200),
                          control1: CGPoint(x: 50, y: 145),
                          control2: CGPoint(x: 48, y: 170))
            ctx.stroke(life, with: .color(lineColor),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // Fate line
            var fate = Path()
            fate.move(to: CGPoint(x: 105, y: 215))
            fate.addQuadCurve(to: CGPoint(x: 100, y: 130), control: CGPoint(x: 102, y: 180))
            ctx.stroke(fate, with: .color(lineColor),
                       style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }
}

// MARK: - Star seal (replaces ConstellationMark)

struct StarSealView: View {
    var size: CGFloat = 44
    var color: Color = P.vermillion

    var body: some View {
        Canvas { ctx, _ in
            let s = size / 44.0
            ctx.scaleBy(x: s, y: s)
            let cx: CGFloat = 22, cy: CGFloat = 22

            // Outer circle
            ctx.stroke(Path(ellipseIn: CGRect(x: 2, y: 2, width: 40, height: 40)),
                       with: .color(color), style: StrokeStyle(lineWidth: 0.7))
            // Inner dashed circle
            ctx.stroke(Path(ellipseIn: CGRect(x: 6, y: 6, width: 32, height: 32)),
                       with: .color(color), style: StrokeStyle(lineWidth: 0.4, dash: [1, 2]))

            let pts: [(CGFloat, CGFloat)] = [(13, 16), (22, 24), (32, 14), (20, 32)]
            // Constellation lines
            var lines = Path()
            lines.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            lines.addLine(to: CGPoint(x: cx, y: cy))
            lines.addLine(to: CGPoint(x: pts[2].0, y: pts[2].1))
            var lines2 = Path()
            lines2.move(to: CGPoint(x: cx, y: cy))
            lines2.addLine(to: CGPoint(x: pts[3].0, y: pts[3].1))
            ctx.stroke(lines, with: .color(color), style: StrokeStyle(lineWidth: 0.5))
            ctx.stroke(lines2, with: .color(color), style: StrokeStyle(lineWidth: 0.5))

            for (x, y) in pts {
                ctx.fill(Path(ellipseIn: CGRect(x: x-1.2, y: y-1.2, width: 2.4, height: 2.4)),
                         with: .color(color))
                var cross = Path()
                cross.move(to: CGPoint(x: x-3, y: y)); cross.addLine(to: CGPoint(x: x+3, y: y))
                cross.move(to: CGPoint(x: x, y: y-3)); cross.addLine(to: CGPoint(x: x, y: y+3))
                ctx.stroke(cross, with: .color(color), style: StrokeStyle(lineWidth: 0.4))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Legacy compat shims

struct ConstellationMark: View {
    var size: CGFloat = 36
    var body: some View { StarSealView(size: size) }
}

struct EditorialCard<Content: View>: View {
    let padding: CGFloat
    let content: () -> Content

    init(padding: CGFloat = 14, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(P.paperBright)
            .overlay(
                Rectangle().stroke(P.ruleSoft, lineWidth: 0.6)
            )
    }
}

// MARK: - MysticalTitle shim (keep for legacy callers)

extension View {
    func mysticalTitle() -> some View { self }
}
