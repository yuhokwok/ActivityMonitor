import SwiftUI
import WidgetKit

struct HomeBatteryState: View {
    let rawValue: String
    var fontSize: CGFloat = 8

    private var symbol: String {
        switch rawValue {
        case "charging": "bolt.fill"
        case "full": "checkmark.circle.fill"
        case "unplugged": "battery.100percent"
        default: "questionmark.circle"
        }
    }
    private var stateColor: Color {
        switch rawValue {
        case "charging", "full", "unplugged": HomeColor.green
        default: .white.opacity(0.52)
        }
    }
    private var title: LocalizedStringKey {
        switch rawValue {
        case "charging": "widget.battery.charging"
        case "full": "widget.battery.full"
        case "unplugged": "widget.battery.unplugged"
        default: "widget.battery.unknown"
        }
    }
    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: fontSize, weight: .medium)).foregroundStyle(stateColor)
            .lineLimit(1).minimumScaleFactor(0.62)
    }
}

struct HomeThermalColumn: View {
    let rawValue: String
    let compact: Bool
    private var fraction: CGFloat? { HomeWidgetFormat.thermalFraction(rawValue) }
    private var color: Color { HomeWidgetFormat.thermalColor(rawValue) }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.white.opacity(0.06))
                if let fraction {
                    Capsule().fill(color).frame(width: compact ? 6 : 9, height: (compact ? 24 : 72) * fraction)
                        .padding(.bottom, 4)
                }
            }
            .frame(width: compact ? 12 : 18, height: compact ? 28 : 94)
            .overlay(Capsule().stroke(Color.white.opacity(0.82), lineWidth: compact ? 1 : 1.5))
            .overlay(alignment: .bottom) {
                Circle().fill(fraction == nil ? Color.black : color)
                    .frame(width: compact ? 15 : 24, height: compact ? 15 : 24)
                    .overlay(Circle().stroke(Color.white.opacity(0.82), lineWidth: compact ? 1 : 1.5))
                    .offset(y: compact ? 3 : 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HomeStorageDial: View {
    let fraction: Double?
    let tint: Color

    var body: some View {
        Canvas { context, size in
            HomeGaugeDrawing.draw(in: &context, size: size, fraction: fraction, tint: tint)
        }
    }
}

struct HomeMemoryGauge: View {
    let fraction: Double?

    var body: some View {
        Canvas { context, size in
            HomeGaugeDrawing.draw(in: &context, size: size, fraction: fraction, tint: HomeColor.memory)
        }
    }
}

enum HomeGaugeDrawing {
    static func draw(in context: inout GraphicsContext, size: CGSize, fraction: Double?, tint: Color) {
        let radius = min(size.width / 2 - 2, size.height - 2)
        let center = CGPoint(x: size.width / 2, y: size.height - 2)
        var sector = Path()
        sector.move(to: center)
        sector.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .zero, clockwise: false)
        sector.closeSubpath()
        context.fill(sector, with: .linearGradient(Gradient(colors: [tint.opacity(0.2), tint.opacity(0.02)]), startPoint: .zero, endPoint: center))
        var rim = Path()
        rim.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .zero, clockwise: false)
        context.stroke(rim, with: .color(tint), lineWidth: 1.3)
        for step in 0...10 {
            let angle = Double(step) / 10 * Double.pi
            let x = center.x - cos(angle) * (radius - 4)
            let y = center.y - sin(angle) * (radius - 4)
            context.fill(Path(ellipseIn: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4)), with: .color(tint))
        }
        if let fraction {
            let angle = min(1, max(0, fraction)) * Double.pi
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: CGPoint(x: center.x - cos(angle) * (radius - 7), y: center.y - sin(angle) * (radius - 7)))
            context.stroke(needle, with: .color(tint), lineWidth: 1.5)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)), with: .color(tint))
        }
    }
}

struct HomeBatteryTank: View {
    let level: Double?

    var body: some View {
        GeometryReader { geometry in
            let bodyHeight = geometry.size.height - 5
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.4).fill(.white).frame(width: 9, height: 3)
                    .position(x: geometry.size.width / 2, y: 1.5)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.09))
                    if let level {
                        ZStack(alignment: .bottom) {
                            HomeStaticWave(reversed: true).fill(HomeColor.green.opacity(0.4))
                                .frame(height: max(0, (bodyHeight - 5) * min(1, max(0, level)) + 2))
                            HomeStaticWave(reversed: false).fill(HomeColor.green)
                                .frame(height: max(0, (bodyHeight - 5) * min(1, max(0, level))))
                        }
                        .padding(2.5).clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        Text("—").font(.caption).foregroundStyle(HomeColor.green)
                    }
                    RoundedRectangle(cornerRadius: 5).stroke(.white, lineWidth: 1.5)
                }
                .frame(height: bodyHeight)
            }
        }
    }
}

struct HomeStaticWave: Shape {
    let reversed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let wave = min(4, rect.height * 0.2)
        path.move(to: CGPoint(x: 0, y: wave))
        path.addCurve(to: CGPoint(x: rect.maxX, y: wave),
                      control1: CGPoint(x: rect.width * 0.3, y: reversed ? wave * 3 : -wave),
                      control2: CGPoint(x: rect.width * 0.6, y: reversed ? -wave : wave * 3))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct HomeCapacityValue: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
            Text(verbatim: value).font(.system(size: 15, weight: .light, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
